#!/usr/bin/env bash
# GameOS RE — étape 5 : capture dynamique via module kprobe.
# Compile kp_getters.ko, décharge/recharge le pilote NVIDIA, arme les kprobes sur
# les 3 getters, déclenche le chargement des micrologiciels, et récupère les
# piles d'appel (dump_stack) dans dmesg -> relie chaque getter à son moteur.
#
#   sudo bash ~/gameos/re/kp_run.sh
#
# Perturbateur : coupe Steam et recharge le pilote (TV noire, normal).
# Après coup : rapatrier la sortie puis « sudo reboot ».
set -euo pipefail
KP_SRC="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/gameos/re/kp"
BUILD=/tmp/gameos-kpbuild
OUT_BASE=/var/lib/gameos-re
SYMS=(_nv048615rm _nv048617rm _nv048649rm)
log() { printf '\e[1;32m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31mERREUR : %s\e[0m\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "à lancer en root (sudo)."

log "Compilation du module kprobe"
rm -rf "$BUILD"; mkdir -p "$BUILD"
cp "$KP_SRC/kp_getters.c" "$KP_SRC/Makefile" "$BUILD/"
make -C "$BUILD" >/dev/null || die "echec compilation du module."
KO="$BUILD/kp_getters.ko"

unload_nvidia() {
    log "Arrêt de la session graphique et déchargement du pilote NVIDIA"
    systemctl isolate multi-user.target
    systemctl stop nvidia-persistenced 2>/dev/null || true
    sleep 3
    for v in /sys/class/vtconsole/vtcon*/bind; do echo 0 > "$v" 2>/dev/null || true; done
    local m
    for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do
        lsmod | grep -q "^$m " && { rmmod "$m" || die "rmmod $m impossible. « sudo reboot »."; }
    done
}

OUT="$OUT_BASE/kp-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
log "Sortie : $OUT"

GPU_PCI="$(lspci -D -d 10de: | awk '/VGA|3D/ {print $1; exit}')"
[[ -n "$GPU_PCI" ]] || die "GPU NVIDIA introuvable."
echo "  GPU PCI : $GPU_PCI"

# Stratégie : enregistrer les kprobes PAR NOM pendant que nvidia est chargé, puis
# décharger nvidia (le cadre kprobe garde la sonde, désarmée) et le recharger
# (ré-armement à MODULE_STATE_COMING, avant module_init) -> on attrape l'appel
# aux getters pendant la 1re init = chargement du firmware. kp_getters reste
# chargé tout du long.

# 1) nvidia doit être chargé pour que l'enregistrement par nom résolve le symbole.
lsmod | grep -q '^nvidia ' || { log "Chargement initial de nvidia"; modprobe nvidia; sleep 1; }

log "Insertion du module kprobe (armement par nom sur nvidia chargé)"
insmod "$KO" || die "insmod a échoué."
dmesg | grep GAMEOS_KP || true
dmesg | grep -q 'GAMEOS_KP armed' || die "aucune sonde armée (symbole non résolu ?)."

log "Déchargement de nvidia (les kprobes restent enregistrés, désarmés)"
unload_nvidia

log "Rechargement de nvidia -> ré-armement avant module_init + firmware (tracé)"
dmesg -C
modprobe nvidia
sleep 2
nvidia-smi > "$OUT/nvidia-smi-init.txt" 2>&1 || true
sleep 2

log "Récupération des piles d'appel"
dmesg > "$OUT/dmesg-full.txt"
# Chaque hit suivi de sa pile (~40 lignes de Call Trace).
grep -A 45 'GAMEOS_KP hit' "$OUT/dmesg-full.txt" > "$OUT/stacks.txt" || true
{
    echo "Hits par getter :"
    for g in g615 g617 g649; do
        printf '  %s : %s\n' "$g" "$(grep -c "GAMEOS_KP hit $g" "$OUT/dmesg-full.txt" || echo 0)"
    done
} | tee "$OUT/summary.txt"

log "Déchargement du module kprobe"
rmmod kp_getters 2>/dev/null || true
chmod -R a+rX "$OUT"
log "Sorties : $OUT/stacks.txt , $OUT/summary.txt , $OUT/dmesg-full.txt"
log "Terminé. Rapatrie la sortie puis « sudo reboot » pour retrouver Steam."
