#!/usr/bin/env bash
# Reconnaissance de nv-kernel.o_binary pour préparer le désassemblage :
# sections, ampleur de l'anonymisation, emplacement des chaînes de registre du
# PMU, et plus gros objets .rodata/.data (candidats micrologiciels).
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

echo "=== Sections (taille, offset fichier) ==="
readelf -SW "$B" | grep -E '\.text|\.data|\.rodata|\.bss|\.rela'

echo
echo "=== Désassembleurs disponibles ==="
for t in objdump rizin r2 radare2 ghidra; do command -v "$t" >/dev/null && echo "  $t : $(command -v "$t")"; done

echo
echo "=== Chaînes de registre liées au PMU (offset fichier) ==="
strings -t x "$B" | grep -E 'RmPmu|PMU ucode|PmuBootstrap' | head

echo
echo "=== 15 plus gros symboles en .rodata (section 5) et .data (section 3) ==="
# Résout l'index de section sans awk (PowerShell casse les scripts awk).
readelf -sW "$B" | grep -E ' OBJECT ' | grep -E ' (3|5) _nv' \
  | sort -k3 -r | head -15

echo
echo "=== .rela.text : nombre de relocations (xrefs code->data exploitables) ==="
readelf -rW "$B" 2>/dev/null | grep -c R_X86_64 || true
