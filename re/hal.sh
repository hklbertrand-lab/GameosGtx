#!/usr/bin/env bash
# Etape 4 : desassemble les 2 constructeurs de la table HAL et en extrait
# toutes les affectations de pointeurs. rizin par stdin (seule methode qui marche).
set -euo pipefail
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/hal.rz" ./hal.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

rizin -q "$B" < hal.rz 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' > hal.dis
echo "hal.dis: $(wc -l < hal.dis) lignes"

echo "=== toutes les affectations [rdi + champ], <imm>  (= entrees de table) ==="
grep -nE 'mov .*\[.*\],' hal.dis | grep -oE 'sym\._nv[0-9]+rm\], 0x[0-9a-f]+' | sort -u

echo "=== lignes mentionnant la base PMU 0x10a0 ==="
grep -nE '0x10a[0-9a-f]{3}' hal.dis || echo "(aucune mention directe de 0x10a0xx)"

echo "=== taille des 2 fonctions ==="
grep -nE '^/ \(fcn\)|; CALL XREF|^[0-9]+:' hal.dis >/dev/null 2>&1 || true
head -3 hal.dis
