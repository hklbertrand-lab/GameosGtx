#!/usr/bin/env bash
# Désassemble les 3 getters isolément (rapide) et cherche des chaînes de moteur.
set -euo pipefail
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/getters.rz" ./getters.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary

echo "########## DESASSEMBLAGE DES GETTERS ##########"
rizin -q "$B" < getters.rz 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'

echo
echo "########## CHAINES MOTEUR DANS TOUT LE BINAIRE ##########"
# Chaînes susceptibles d'identifier les falcons signés.
strings -tx "$B" | grep -iE '\b(pmu|sec2|gpccs|fecs|gsp|nvdec|minion|ucode|falcon)\b' \
    | grep -ivE 'gspromresetonfailure' | sort -k2 | head -60
