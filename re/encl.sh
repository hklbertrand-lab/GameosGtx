#!/usr/bin/env bash
# Fonctions GeForce manipulant la base falcon PMU 0x0010a000, via text.dis.
# objdump AT&T imprime l'immediat $0x10a000 (sans zeros de tete). On veut
# EXACTEMENT 0x10a000 (pas 0x10a0000), donc pas suivi d'un autre chiffre hexa.
set +e
cd "$HOME/gameos-re3"
[ -s text.dis ] || { echo "text.dis absent"; exit 1; }

echo "=== sites immediat \$0x10a000 (base PMU) ==="
grep -nE '\$0x10a000[^0-9a-f]' text.dis > /tmp/pmusites.txt
wc -l /tmp/pmusites.txt
grep -nE '^[0-9a-f]+ <.*>:$' text.dis > /tmp/labels.txt

echo "=== fonction englobante de chaque site ==="
while IFS=: read -r ln rest; do
    fn=$(awk -F: -v L="$ln" '$1<=L{n=$0} END{print n}' /tmp/labels.txt | sed -E 's/^[0-9]+:[0-9a-f]+ <(.*)>:$/\1/')
    echo "$fn"
done < /tmp/pmusites.txt | sort | uniq -c | sort -rn
