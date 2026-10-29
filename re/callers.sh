#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/gameos-re3"

echo "=== ligne d'appel exacte (format brut) ==="
grep -nE 'call.*<_nv048615rm>$' text.dis | head -2

# Construit la table edge en gardant uniquement les cibles <symbole> (offset 0).
# Robuste au format: on isole le dernier champ <...> et on exige l'absence de +.
awk '
  /^[0-9a-f]+ <.*>:$/ { lbl=$2; gsub(/[<>:]/,"",lbl); next }
  /\tcall/ || / call / {
    tgt=$NF
    if (tgt ~ /^<_nv[0-9]+rm>$/) {
      gsub(/[<>]/,"",tgt)
      if (tgt != lbl) print lbl, tgt
    }
  }' text.dis | sort -u > edges0.txt
echo "edges(offset0): $(wc -l < edges0.txt)"
echo "--- echantillon ---"; head edges0.txt

up() {
    local lvl="$1" d nxt
    echo "=== remontee depuis $1 ==="
    for d in 1 2 3 4; do
        nxt=$(awk -v L=" $lvl " 'index(L," "$2" "){print $1}' edges0.txt | sort -u | tr '\n' ' ')
        echo "  niveau $d: ${nxt:-<aucun>}"
        [ -n "$nxt" ] || break
        lvl="$nxt"
    done
}
up _nv048615rm
up _nv048617rm
up _nv048649rm
