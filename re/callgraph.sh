#!/usr/bin/env bash
# Étape 3 : graphe d'appels de nv-kernel.o_binary.
#   start  : lance en fond (nohup) rizin aaa + objdump -d complet
#   status : avancement
#   graph  : remonte les appelants des 3 fournisseuses de micrologiciel
# Les appels internes à .text n'ont pas de relocation dans un .o, mais
# objdump résout le rel32 en <symbole+off> : un simple grep suffit.
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
W=$HOME/gameos-re3
mkdir -p "$W"
cd "$W"

case "${1:-status}" in
start)
    if ! [ -s text.dis ]; then
        nohup sh -c "objdump -d --no-show-raw-insn -j .text '$B' > text.dis.tmp && mv text.dis.tmp text.dis" \
            > objdump.log 2>&1 &
        echo "objdump pid $!"
    fi
    if ! [ -s aaa.done ]; then
        nohup sh -c "rizin -q -e bin.relocs.apply=true -e anal.timeout=0 \
            -c 'aaa; aflj > funcs.json; agCj > callgraph.json; Ps aaa.rzdb' '$B' \
            && date > aaa.done" > rizin.log 2>&1 &
        echo "rizin pid $!"
    fi
    ;;
status)
    ls -la "$W"
    pgrep -a objdump || true
    pgrep -a rizin || true
    tail -3 rizin.log 2>/dev/null || true
    ;;
graph)
    [ -s text.dis ] || { echo "text.dis pas prêt"; exit 1; }
    # appelant(fonction englobante) -> cible, pour tout call direct
    awk '/^[0-9a-f]+ <.*>:$/ { f=$2; gsub(/[<>:]/,"",f) }
         /\tcall +[0-9a-f]+ <[^>]+>/ { t=$NF; gsub(/[<>]/,"",t); sub(/\+0x.*/,"",t); print f, t }' \
         text.dis | sort -u > edges.txt
    wc -l edges.txt
    # remontée sur 4 niveaux depuis chaque fournisseuse
    for g in _nv048615rm _nv048617rm _nv048649rm; do
        echo "=== $g ==="
        lvl="$g"
        for d in 1 2 3 4; do
            nxt=$(awk -v L=" $lvl " 'index(L," "$2" ") && $1!=$2 {print $1}' edges.txt | sort -u | tr '\n' ' ')
            echo "  niveau $d: $nxt"
            [ -n "$nxt" ] || break
            lvl="$nxt"
        done
    done
    # fonctions qui manipulent la base PMU 0x10a000 (immédiat 0x10axxx)
    echo "=== fonctions touchant 0x10a0xx-0x10afff ==="
    awk '/^[0-9a-f]+ <.*>:$/ { f=$2; gsub(/[<>:]/,"",f) }
         /\$0x10a[0-9a-f][0-9a-f][0-9a-f][,)]/ || /0x10a[0-9a-f][0-9a-f][0-9a-f]\(/ { print f }' \
         text.dis | sort | uniq -c | sort -rn | head -40 > pmu_funcs.txt
    cat pmu_funcs.txt
    ;;
esac
