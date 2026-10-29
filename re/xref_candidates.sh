#!/usr/bin/env bash
# Pour chaque bloc candidat, liste les relocations de .text/.data qui le référencent
# (r_offset = emplacement du code/pointeur qui pointe vers le micrologiciel).
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
REL=/tmp/gameos-rela.txt
# Les relocations sont volumineuses : on les extrait une fois.
[[ -f $REL ]] || readelf -rW "$B" > "$REL"

for s in _nv046226rm _nv056765rm _nv056766rm _nv046224rm _nv046225rm; do
    echo "=== $s ==="
    grep -E " $s(\$| |\+)" "$REL" | head -12
    printf "  total refs : "; grep -cE " $s(\$| |\+)" "$REL"
done
