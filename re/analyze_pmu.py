#!/usr/bin/env python3
# GameOS RE — étape 2a : repérer dans une trace mmiotrace les accès du pilote
# aux processeurs internes PMU et SEC2 de la GP102, et les opérations de copie
# (DMA) qui chargent les micrologiciels. Lecture en flux : on ne charge jamais
# tout le fichier en mémoire.
#
#   analyze_pmu.py <mmiotrace.txt|.zst> <dossier_sortie>
#
# Entrée : lignes mmiotrace. Un accès registre a la forme
#   R|W <largeur> <ts> <id_map> <adresse> <valeur> <pc> <compte>
# MARK marque un scénario, MAP/UNMAP associent un id à une plage BAR.
import sys, os, lzma, re
from collections import defaultdict, Counter

# Décalages des blocs Falcon dans la BAR0 du GP102 (doc openrm / nouveau).
BLOCKS = {
    "PMU":  (0x10a000, 0x10b000),   # gère fréquences, tensions, températures
    "SEC2": (0x840000, 0x841000),   # vérifie les signatures, lance le PMU en mode sûr
    "FB":   (0x100000, 0x100f00),   # contrôleur mémoire (fenêtre de copie firmware)
}
# Registres Falcon notables, en décalage depuis la base du bloc.
FALCON_REGS = {
    0x040: "DMACTL", 0x048: "DMATRFBASE", 0x04c: "DMATRFMOFFS",
    0x050: "DMATRFCMD", 0x054: "DMATRFFBOFFS", 0x100: "BOOTVEC",
    0x104: "CPUCTL", 0x10c: "IRQSCLR", 0x180: "MAILBOX0", 0x184: "MAILBOX1",
    0x1c0: "IMEMC", 0x1c4: "IMEMD", 0x1c8: "IMEMT",
    0x1e0: "DMEMC0", 0x1e4: "DMEMD0", 0x200: "SCTL", 0x240: "DMATRFBASE1",
}

def open_any(path):
    if path.endswith(".zst"):
        import subprocess
        p = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE, text=True, bufsize=1)
        return p.stdout
    if path.endswith(".xz"):
        return lzma.open(path, "rt")
    return open(path, "r", errors="replace")

def block_of(addr):
    for name, (lo, hi) in BLOCKS.items():
        if lo <= addr < hi:
            return name, addr - lo
    return None, None

def main():
    src, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    scenario = "pre"
    # id de MAP -> adresse physique de base. mmiotrace donne des adresses physiques ;
    # le décalage registre = adresse - base de la plage BAR0 (la grande : len 0x1000000).
    map_base = {}
    bar0 = {}  # id -> True si c'est la BAR0 (16 Mo)
    # Par scénario : nombre d'accès à chaque bloc + liste brute des accès PMU/SEC2.
    per = defaultdict(lambda: {"PMU": 0, "SEC2": 0, "FB": 0})
    falcon_log = open(os.path.join(outdir, "falcon-accesses.txt"), "w")
    falcon_log.write("# scenario op block reg off addr value pc\n")
    dma = open(os.path.join(outdir, "dma-events.txt"), "w")
    dma.write("# scenario : écritures DMATRF* / BOOTVEC / CPUCTL (chargement + lancement firmware)\n")
    imem_runs = defaultdict(int)  # (scenario,block) -> octets écrits via IMEMD (code en clair)
    reg_hits = Counter()
    n = 0
    for line in src_lines:
        n += 1
        if line.startswith("MARK"):
            parts = line.split("GAMEOS", 1)
            if len(parts) == 2:
                scenario = parts[1].split()[0]
            continue
        if line.startswith("MAP"):
            # MAP ts id phys virt len ...
            m = line.split()
            try:
                mid = m[2]; phys = int(m[3], 16); length = int(m[5], 16)
            except (IndexError, ValueError):
                continue
            map_base[mid] = phys
            bar0[mid] = (length >= 0x1000000)   # BAR0 = 16 Mo, les registres sont là
            continue
        if line.startswith("UNMAP"):
            continue
        if not (line and line[0] in "RW" and line[1] == " "):
            continue
        f = line.split()
        if len(f) < 6:
            continue
        mid = f[3]
        if not bar0.get(mid):   # on ne garde que les accès à la BAR0
            continue
        try:
            addr = int(f[4], 16); val = int(f[5], 16)
        except ValueError:
            continue
        off_bar = addr - map_base.get(mid, 0)
        blk, off = block_of(off_bar)
        if blk is None:
            continue
        per[scenario][blk] += 1
        reg = FALCON_REGS.get(off, f"0x{off:03x}")
        reg_hits[(blk, reg)] += 1
        falcon_log.write(f"{scenario} {f[0]} {blk} {reg} 0x{off:03x} 0x{addr:x} 0x{val:x} {f[6] if len(f)>6 else '-'}\n")
        if reg in ("DMATRFBASE", "DMATRFMOFFS", "DMATRFCMD", "DMATRFFBOFFS",
                   "DMATRFBASE1", "BOOTVEC", "CPUCTL", "DMACTL", "SCTL"):
            dma.write(f"{scenario} {blk} {reg} 0x{val:x}\n")
        if reg == "IMEMD" and f[0] == "W":
            imem_runs[(scenario, blk)] += 4
    falcon_log.close(); dma.close()

    with open(os.path.join(outdir, "summary.txt"), "w") as s:
        s.write(f"Lignes lues : {n}\n\nAccès par scénario et par bloc :\n")
        for sc, d in per.items():
            s.write(f"  {sc:6} PMU={d['PMU']:>8} SEC2={d['SEC2']:>8} FB={d['FB']:>8}\n")
        s.write("\nOctets écrits directement dans l'IMEM (code Falcon en clair) :\n")
        for (sc, blk), nbytes in sorted(imem_runs.items()):
            s.write(f"  {sc:6} {blk:5} {nbytes} octets\n")
        s.write("\nRegistres Falcon les plus touchés :\n")
        for (blk, reg), c in reg_hits.most_common(30):
            s.write(f"  {blk:5} {reg:12} {c}\n")
    print(open(os.path.join(outdir, "summary.txt")).read())

if __name__ == "__main__":
    src_lines = open_any(sys.argv[1])
    main()
