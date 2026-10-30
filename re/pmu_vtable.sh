#!/usr/bin/env bash
# Cherche ou les methodes PMU sont rangees comme POINTEURS (R_X86_64_64) :
# c'est la ou la table HAL PMU est construite. De la on remontera au getter d'ucode.
set +e
cd "$HOME/gameos-re3"
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

echo "=== relocs DATA (R_X86_64_64) vers les methodes PMU ==="
objdump -r "$B" 2>/dev/null | grep -E 'R_X86_64_64 .*_nv(030978|052191|052193|052194|030959|030960)rm' | head -40

echo
echo "=== qui prend l'adresse de _nv030978rm (primitive registre) ? toutes relocs ==="
objdump -r "$B" 2>/dev/null | grep -E '_nv030978rm' | head -40
