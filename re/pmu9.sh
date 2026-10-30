#!/usr/bin/env bash
# Desassemble (relocations) les 9 fonctions PMU GeForce ; resume taille, relocs
# data (candidat ucode), et offsets falcon ecrits.
set +e
cd "$HOME/gameos-re3"
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

start_of() { grep -E "<$1>:$" text.dis | head -1 | awk '{print $1}'; }
next_lbl() { awk -v s="0x$1" 'BEGIN{S=strtonum(s)} /^[0-9a-f]+ </{a=strtonum("0x"$1); if(a>S){print $1; exit}}' text.dis; }

for f in _nv052516rm _nv030959rm _nv030960rm _nv052223rm _nv052168rm _nv052166rm _nv052191rm _nv052193rm _nv052194rm; do
    s=$(start_of "$f"); [ -n "$s" ] || { echo "## $f introuvable"; continue; }
    e=$(next_lbl "$s")
    sz=$(( 0x${e:-$s} - 0x$s ))
    printf '\n################## %s  [0x%s] taille~%d o ##################\n' "$f" "$s" "$sz"
    objdump -dr --start-address=0x$s --stop-address=0x${e:-$s} "$B" 2>/dev/null \
        | grep -iE 'R_X86_64|call +[0-9a-f]+ <|0x5e00|0x50,|DMATRF|,%e.i *$' | head -40
done
