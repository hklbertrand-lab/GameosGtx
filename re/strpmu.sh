#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/strpmu.rz" ./strpmu.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
rizin -q "$B" < strpmu.rz 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
echo '===== SCAN CHAINES MOTEUR ====='
strings -tx "$B" | grep -iE 'pmu|sec2|gpccs|fecs|falcon ucode|[^a-z]gsp[^a-z]' | head -50
