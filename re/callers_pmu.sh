#!/usr/bin/env bash
# Appelants des fonctions PMU GeForce, via text.dis (objdump resout call <sym>).
set +e
cd "$HOME/gameos-re3"
[ -s text.dis ] || { echo "text.dis absent"; exit 1; }
grep -nE '^[0-9a-f]+ <.*>:$' text.dis > /tmp/labels.txt

PMU="_nv052191rm _nv052193rm _nv052194rm _nv052516rm _nv052223rm _nv052168rm _nv052166rm _nv030959rm _nv030960rm"

encl() {  # numero de ligne -> nom de fonction englobante
    awk -F: -v L="$1" '$1<=L{n=$0} END{print n}' /tmp/labels.txt \
        | sed -E 's/^[0-9]+:[0-9a-f]+ <(.*)>:$/\1/'
}

for f in $PMU; do
    echo "===== appelants de $f ====="
    # lignes 'call ... <f>' (offset 0, pas <f+0x..>)
    grep -nE "call +[0-9a-f]+ <$f>\$" text.dis | while IFS=: read -r ln _; do
        c=$(encl "$ln")
        [ "$c" != "$f" ] && echo "  $c"
    done | sort | uniq -c | sort -rn
done
