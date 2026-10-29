#!/usr/bin/env bash
# GameOS RE — étape 5 : analyse dynamique.
# Pose un kprobe sur chacun des 3 getters de micrologiciel, capture la PILE
# D'APPEL quand ils s'exécutent (au chargement des micrologiciels), puis range
# la trace dans /var/lib/gameos-re/kprobe-<date>/.
#
# La pile d'appel révèle QUEL moteur appelle quel getter -> relie enfin le PMU
# (base 0x10a000) à son getter de micrologiciel.
#
#   sudo bash ~/gameos/re/kprobe_getters.sh
#
# Perturbateur : coupe la session Steam et recharge le pilote (TV noire, normal).
# Après coup : « sudo reboot » revient au démarrage normal (Steam).
set -euo pipefail

TRACING=/sys/kernel/tracing
OUT_BASE=/var/lib/gameos-re
GROUP=getters
log() { printf '\e[1;32m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31mERREUR : %s\e[0m\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "à lancer en root (sudo)."

cleanup_probes() {
    echo 0 > "$TRACING/events/$GROUP/enable" 2>/dev/null || true
    echo 0 > "$TRACING/options/stacktrace" 2>/dev/null || true
    : > "$TRACING/kprobe_events" 2>/dev/null || true
}
trap cleanup_probes EXIT

# Enregistre les 3 kprobes. Les symboles _nvXXXXrm sont LOCAUX au module : la
# forme « nvidia:SYM » est requise (le nom seul donne EINVAL). On tente les deux
# formes par sécurité et on signale, par getter, laquelle a pris.
arm_probes() {
    : > "$TRACING/kprobe_events"
    local ok=0 name sym spec
    # Le site d'entrée (fentry) est refusé (« notrace function ») : on pose le
    # kprobe à un offset au-delà du prologue (endbr64;push rbp;mov rbp,rsp = 8o)
    # -> kprobe int3 classique, hors du chemin ftrace. On essaie plusieurs formes.
    for pair in g615:_nv048615rm g617:_nv048617rm g649:_nv048649rm; do
        name="${pair%%:*}"; sym="${pair#*:}"
        local done=0
        for spec in "nvidia:$sym+8" "$sym+8" "nvidia:$sym+5" "$sym+5" "nvidia:$sym" "$sym"; do
            if echo "p:$GROUP/$name $spec" >> "$TRACING/kprobe_events" 2>/dev/null; then
                echo "  $name <- $spec"; ok=$((ok+1)); done=1; break
            fi
        done
        [[ $done -eq 1 ]] || echo "  $name : ECHEC pour $sym"
    done
    [[ $ok -gt 0 ]] || { dmesg | tail -8; die "aucun kprobe enregistré (voir dmesg ci-dessus)."; }
}

# Mode diagnostic : teste l'enregistrement sur le pilote DÉJÀ chargé, sans rien
# décharger ni recouper l'affichage, puis nettoie. Pour trouver la bonne syntaxe
# à moindre coût avant la vraie capture.
cmd_diag() {
    lsmod | grep -q '^nvidia ' || die "module nvidia non chargé : lance plutôt la capture complète."
    log "DIAGNOSTIC (aucune perturbation) — test d'enregistrement des kprobes"
    arm_probes
    echo "--- kprobe_events actifs ---"; cat "$TRACING/kprobe_events"
    cleanup_probes
    trap - EXIT
    log "OK : note quelle forme a pris, puis lance la capture complète (sans argument)."
}

unload_nvidia() {
    log "Arrêt de la session graphique et déchargement du pilote NVIDIA"
    systemctl isolate multi-user.target
    systemctl stop nvidia-persistenced 2>/dev/null || true
    sleep 3
    for v in /sys/class/vtconsole/vtcon*/bind; do echo 0 > "$v" 2>/dev/null || true; done
    local m
    for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do
        if lsmod | grep -q "^$m "; then
            rmmod "$m" || die "impossible de décharger $m (encore utilisé ?). « sudo reboot » pour revenir."
        fi
    done
}

cmd_run() {
OUT="$OUT_BASE/kprobe-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
log "Sortie : $OUT"

# Pilote déchargé pour que l'init (et le chargement des micrologiciels) se rejoue
# APRÈS l'armement des kprobes.
lsmod | grep -q '^nvidia' && unload_nvidia

# Les symboles de module ne sont kprobables par nom que si le module est chargé.
# On charge donc nvidia SANS init GPU, on arme, puis on déclenche l'init via nvidia-smi.
log "Chargement du module (sans init GPU)"
modprobe nvidia

log "Armement des kprobes sur les 3 getters (+ pile d'appel)"
arm_probes   # défini plus haut ; die en cas d'échec total

echo nop > "$TRACING/current_tracer"
echo > "$TRACING/trace"
echo 1 > "$TRACING/options/stacktrace"   # pile d'appel après chaque événement
echo 1 > "$TRACING/events/$GROUP/enable"
echo 1 > "$TRACING/tracing_on"

log "Déclenchement de l'init GPU / chargement des micrologiciels"
modprobe nvidia_uvm 2>/dev/null || true
modprobe nvidia_modeset 2>/dev/null || true
nvidia-smi > "$OUT/nvidia-smi-init.txt" 2>&1 || true
sleep 2

echo 0 > "$TRACING/tracing_on"
cp "$TRACING/trace" "$OUT/kprobe-trace.txt"
cp "$TRACING/kprobe_events" "$OUT/kprobe-events.txt" 2>/dev/null || true

# Combien de fois chaque getter a été touché
log "Récapitulatif"
grep -cE ' g615:| g617:| g649:' "$OUT/kprobe-trace.txt" > /dev/null 2>&1 || true
for g in g615 g617 g649; do
    printf '  %s : %s hits\n' "$g" "$(grep -c "$g:" "$OUT/kprobe-trace.txt" || echo 0)"
done | tee "$OUT/summary.txt"

chmod -R a+rX "$OUT"
cleanup_probes
trap - EXIT
log "Trace dans $OUT/kprobe-trace.txt"
log "Terminé. Rapatrie la trace puis « sudo reboot » pour retrouver Steam."
}

case "${1:-run}" in
    diag) cmd_diag ;;
    run)  cmd_run ;;
    *) die "usage : $0 {diag|run}" ;;
esac
