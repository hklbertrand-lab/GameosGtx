#!/usr/bin/env bash
# Désassemble (objdump) le contexte des sites .text qui référencent les blocs
# candidats. objdump -dr annote les relocations : on voit directement les
# symboles référencés (micrologiciel, et fonctions appelées autour).
set -euo pipefail
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

site() {   # $1=nom  $2=adresse(hex sans 0x)
    local a=$((0x$2))
    printf '\n############## %s  @ 0x%x ##############\n' "$1" "$a"
    objdump -dr --start-address=$((a-0x200)) --stop-address=$((a+0x30)) "$B" \
        | sed -n '/>:/,$p' | tail -80
}

site "046226 (95K seul)"    e6556f
site "056765/6 (72K paire)" e19a20
site "046224/5 (48K paire)" e173b3
