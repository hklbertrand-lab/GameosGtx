#!/usr/bin/env bash
# Désassemble (avec relocations) les fonctions PMU GeForce et cherche le
# bootstrap : écritures falcon (DMATRFBASE/BOOTVEC/CPUCTL) + reloc vers un blob
# de données (micrologiciel PMU).
set +e
cd "$HOME/gameos-re3"
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
grep -nE '^[0-9a-f]+ <.*>:$' text.dis > /tmp/labels.txt

dump_fn() {   # $1 = nom
    local name="$1"
    # offset de debut (hex) et offset du label suivant (fin)
    local start end
    start=$(grep -E "<$name>:$" text.dis | head -1 | awk '{print $1}')
    [ -n "$start" ] || { echo "## $name : introuvable"; return; }
    end=$(awk -v s="0x$start" 'BEGIN{S=strtonum(s)} /^[0-9a-f]+ </{a=strtonum("0x"$1); if(a>S){print $1; exit}}' text.dis)
    printf '\n################## %s  [0x%s .. 0x%s] ##################\n' "$name" "$start" "${end:-fin}"
    if [ -n "$end" ]; then
        objdump -dr --start-address=0x$start --stop-address=0x$end "$B" 2>/dev/null | sed -n '/>:/,$p'
    fi
}

for f in _nv052191rm _nv052193rm _nv052194rm; do
    dump_fn "$f" | grep -iE 'RELOC|0x10a0|call|movabs|lea ' | head -60
done
