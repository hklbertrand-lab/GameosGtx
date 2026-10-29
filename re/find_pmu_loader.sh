#!/usr/bin/env bash
# Remonte des 3 fonctions fournisseuses de micrologiciel à leurs appelants,
# et repère celui qui manipule la base Falcon du PMU (0x0010a0xx) : c'est lui
# qui charge le micrologiciel PMU, donc son jeu est le bon.
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
REL=/tmp/gameos-rela.txt
[[ -f $REL ]] || readelf -rW "$B" > "$REL"

for fn in _nv048615rm _nv048617rm _nv048649rm; do
    echo "######## appelants de $fn ########"
    # Sites d'appel : relocations PC32 vers la fonction.
    sites=$(grep -E "R_X86_64_PC32 *$fn([-+]|$| )" "$REL" | awk '{print $1}')
    for off in $sites; do
        a=$((0x$off))
        # Fonction englobant l'appel (dernier symbole <foo>: avant le site).
        fname=$(objdump -d --start-address=$((a-0x1200)) --stop-address=$((a+4)) "$B" \
                | grep -oE '<_nv[0-9]+rm>:' | tail -1)
        # La fonction appelante touche-t-elle la base PMU 0x10a0xx ?
        pmu=$(objdump -d --start-address=$((a-0x1200)) --stop-address=$((a+0x400)) "$B" \
              | grep -ciE '\$0x10a0[0-9a-f][0-9a-f]|,0x10a0[0-9a-f][0-9a-f]')
        printf "  appel @0x%x  dans %-16s  refs_base_PMU=%s\n" "$a" "$fname" "$pmu"
    done
done
