#!/usr/bin/env python3
# GameOS RE — étape 2b : cartographier nv-kernel.o_binary pour localiser les
# micrologiciels Falcon embarqués (dont le PMU GP102). Deux signaux :
#   1. entropie par fenêtre : le code x86 a une entropie modérée (~6), les
#      images signées/chiffrées sont proches de 8. Les blobs firmware ressortent.
#   2. table des chaînes : noms de symboles (pmu, gp102, ucode, falcon, sec2…)
#      souvent proches des blobs, pour nommer les régions.
#
#   scan_driver.py <nv-kernel.o_binary> <dossier_sortie>
import sys, os, math
from collections import defaultdict

WIN = 4096
HIGH = 7.5            # seuil d'entropie « image signée »
KEYWORDS = [b"pmu", b"PMU", b"gp102", b"GP102", b"gp10x", b"ucode", b"Ucode",
            b"falcon", b"Falcon", b"sec2", b"SEC2", b"acr", b"booter",
            b"bootloader", b"AppVersion", b"nvPmu", b"g_pmu", b"riscv", b"gsp"]

def entropy(b):
    if not b:
        return 0.0
    c = [0] * 256
    for x in b:
        c[x] += 1
    n = len(b); e = 0.0
    for v in c:
        if v:
            p = v / n
            e -= p * math.log2(p)
    return e

def scan_entropy(path, out):
    regions = []      # (start, end) des zones à haute entropie, fusionnées
    cur = None
    off = 0
    hist = defaultdict(int)
    with open(path, "rb") as f:
        while True:
            w = f.read(WIN)
            if not w:
                break
            e = entropy(w)
            hist[round(e)] += 1
            if e >= HIGH:
                if cur is None:
                    cur = [off, off + len(w)]
                else:
                    cur[1] = off + len(w)
            else:
                if cur is not None:
                    regions.append(tuple(cur)); cur = None
            off += len(w)
    if cur is not None:
        regions.append(tuple(cur))
    with open(os.path.join(out, "entropy-regions.txt"), "w") as g:
        g.write("# régions à haute entropie (candidats firmware signé)\n")
        g.write("# start_hex       taille(Ko)\n")
        for a, b in regions:
            if b - a >= 2048:      # ignorer le bruit < 2 Ko
                g.write(f"0x{a:08x}  {(b-a)//1024}\n")
    with open(os.path.join(out, "entropy-histogram.txt"), "w") as g:
        for k in sorted(hist):
            g.write(f"entropie~{k} : {hist[k]} fenêtres\n")
    return [(a, b) for a, b in regions if b - a >= 2048]

def scan_strings(path, out):
    hits = defaultdict(list)
    data = b""
    base = 0
    with open(path, "rb") as f:
        prev = b""
        while True:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            buf = prev + chunk
            for kw in KEYWORDS:
                i = buf.find(kw)
                while i != -1:
                    pos = base - len(prev) + i
                    if len(hits[kw]) < 40:
                        # contexte imprimable autour du hit
                        s = buf[max(0, i - 4):i + 48]
                        printable = bytes(c if 32 <= c < 127 else 46 for c in s)
                        hits[kw].append((pos, printable.decode("ascii", "replace")))
                    i = buf.find(kw, i + 1)
            prev = buf[-64:]
            base += len(chunk)
    with open(os.path.join(out, "symbol-hits.txt"), "w") as g:
        for kw in KEYWORDS:
            g.write(f"\n== {kw.decode()} ({len(hits[kw])} premiers) ==\n")
            for pos, ctx in hits[kw]:
                g.write(f"0x{pos:08x}  {ctx}\n")
    return hits

def main():
    path, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    size = os.path.getsize(path)
    regions = scan_entropy(path, out)
    hits = scan_strings(path, out)
    with open(os.path.join(out, "scan-summary.txt"), "w") as g:
        g.write(f"Binaire : {path} ({size//1024//1024} Mo)\n")
        g.write(f"Régions haute entropie >= 2 Ko : {len(regions)}\n")
        tot = sum(b - a for a, b in regions)
        g.write(f"Volume total haute entropie : {tot//1024} Ko\n\n")
        g.write("Plus grosses régions (candidats firmware) :\n")
        for a, b in sorted(regions, key=lambda r: r[1]-r[0], reverse=True)[:15]:
            g.write(f"  0x{a:08x}  {(b-a)//1024:>6} Ko\n")
        g.write("\nSymboles firmware trouvés :\n")
        for kw in KEYWORDS:
            if hits[kw]:
                g.write(f"  {kw.decode():12} : {len(hits[kw])}+ occurrences, 1re à 0x{hits[kw][0][0]:08x}\n")
    print(open(os.path.join(out, "scan-summary.txt")).read())

if __name__ == "__main__":
    main()
