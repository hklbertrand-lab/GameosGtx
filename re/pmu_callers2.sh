#!/usr/bin/env bash
# Vrais appelants (relocs PC32) des methodes PMU GeForce. L'offset de chaque
# reloc est une adresse dans .text -> fonction englobante via les labels.
set +e
cd "$HOME/gameos-re3"
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

# table labels : addr(dec) nom , triee
grep -E '^[0-9a-f]+ <.*>:$' text.dis \
  | sed -E 's/^([0-9a-f]+) <(.*)>:$/\1 \2/' \
  | awk '{printf "%d %s\n", strtonum("0x"$1), $2}' | sort -n > /tmp/lab.txt

encl() {  # $1 = addr hex -> nom fonction
    awk -v A="$((16#$1))" '$1<=A{n=$2} $1>A{print n; exit} END{print n}' /tmp/lab.txt
}

for f in _nv052191rm _nv052193rm _nv052194rm _nv052166rm _nv052168rm _nv052516rm _nv052223rm; do
    echo "===== appelants (PC32) de $f ====="
    objdump -r "$B" 2>/dev/null | grep -E "R_X86_64_PC32 +$f-" | awk '{print $1}' | while read -r off; do
        encl "$off"
    done | sort | uniq -c | sort -rn
done
