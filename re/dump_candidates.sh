#!/usr/bin/env bash
# Affiche les premiers octets des symboles de données candidats au micrologiciel
# PMU, en calculant leur offset fichier (vaddr - vaddr_section + offset_section).
# Objectif : repérer une structure de descripteur Falcon (en-tête, tailles).
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

# Bases des sections (vaddr et offset fichier), lues une fois.
read RVA ROFF < <(readelf -SW "$B" | sed -n 's/.*\.rodata *PROGBITS *\([0-9a-f]*\) *\([0-9a-f]*\).*/\1 \2/p')
read DVA DOFF < <(readelf -SW "$B" | sed -n 's/.*\.data *PROGBITS *\([0-9a-f]*\) *\([0-9a-f]*\).*/\1 \2/p')
echo "rodata vaddr=0x$RVA off=0x$ROFF    data vaddr=0x$DVA off=0x$DOFF"

dump() {   # $1 = nom symbole
    local line va sz sec foff secva secoff
    line="$(readelf -sW "$B" | grep " $1\$" | head -1)"
    [[ -n "$line" ]] || { echo "  $1 introuvable"; return; }
    va="$(echo "$line" | awk '{print $2}')"
    sz="$(echo "$line" | awk '{print $3}')"
    sec="$(echo "$line" | awk '{print $7}')"
    if [[ "$sec" == 5 ]]; then secva=$RVA; secoff=$ROFF; else secva=$DVA; secoff=$DOFF; fi
    foff=$(( 0x$va - 0x$secva + 0x$secoff ))
    printf "\n=== %s  taille=%s  section=%s  offset_fichier=0x%x ===\n" "$1" "$sz" "$sec" "$foff"
    dd if="$B" bs=1 skip="$foff" count=96 status=none | od -Ax -tx1z
}

for s in _nv046226rm _nv056765rm _nv056766rm _nv029068rm _nv046224rm _nv046225rm \
         _nv046609rm _nv046619rm _nv046660rm _nv046662rm; do
    dump "$s"
done

echo
echo "=== Référence : en-tête du descripteur SEC2 public GP102 ==="
zstd -dc /usr/lib/firmware/nvidia/gp102/sec2/desc.bin.zst 2>/dev/null | od -Ax -tx1z | head -6
