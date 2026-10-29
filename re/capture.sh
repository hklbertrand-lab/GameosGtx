#!/usr/bin/env bash
# GameOS RE — étape 1 : capture mmiotrace du pilote NVIDIA 580 sur la GTX 1080 Ti.
#
#   capture.sh prepare   crée l'entrée systemd-boot « gameos-capture » (pas de
#                        session graphique, modules NVIDIA non chargés au boot),
#                        la programme pour le PROCHAIN démarrage seulement, redémarre.
#                        Inutile avec un démarrage UKI : « run » décharge alors le pilote à chaud.
#   capture.sh run       (via SSH) trace : chargement du
#                        pilote + init GPU, changements de fréquences et de limite
#                        de puissance. Range tout dans /var/lib/gameos-re/<date>/.
#   capture.sh status    indique si on est dans le boot de capture.
#
# Après « run », un simple reboot revient au démarrage normal (Steam).
# À lancer en root (installé dans /usr/local/sbin, voir re/README.md).
set -euo pipefail

ENTRY_NAME=gameos-capture.conf
ENTRIES=/boot/loader/entries
OUT_BASE=/var/lib/gameos-re
TRACING=/sys/kernel/tracing
NV_MODS=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm
GPU_PCI="$(lspci -D -d 10de: | awk '/VGA/ {print $1; exit}')"

log() { printf '\e[1;32m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31mERREUR : %s\e[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "à lancer en root (sudo)."
[[ -n "$GPU_PCI" ]] || die "aucun GPU NVIDIA trouvé."

in_capture_boot() { grep -q 'gameos_capture=1' /proc/cmdline; }

mark() {
    # Les marqueurs apparaissent dans la trace (lignes MARK) : ils découpent les scénarios.
    echo "GAMEOS $*" > "$TRACING/trace_marker"
    echo "[$(date +%T)] $*" >> "$OUT/scenarios.log"
    sleep 1
}

cmd_prepare() {
    [[ -d $ENTRIES ]] || die "$ENTRIES introuvable (démarrage UKI ?) : inutile, lance directement « $0 run »."
    local base
    base="$(grep -l '^linux */vmlinuz-linux$' "$ENTRIES"/*.conf | grep -v -e fallback -e "$ENTRY_NAME" | head -n1)"
    [[ -n "$base" ]] || die "entrée de démarrage du noyau « linux » introuvable."
    log "Entrée de base : $base"
    # modprobe.blacklist : bloque le chargement automatique (udev, initramfs via modprobe -b)
    # mais laisse « modprobe nvidia » explicite fonctionner, contrairement à module_blacklist.
    sed -e 's/^title .*/title GameOS - capture mmiotrace/' \
        -e "s/^options .*/& modprobe.blacklist=$NV_MODS systemd.unit=multi-user.target gameos_capture=1/" \
        "$base" > "$ENTRIES/$ENTRY_NAME"
    cat "$ENTRIES/$ENTRY_NAME"
    bootctl set-oneshot "$ENTRY_NAME"
    log "Prochain démarrage (une seule fois) : capture. Redémarrage dans 5 s…"
    log "Reconnecte-toi ensuite en SSH et lance : sudo gameos-capture run"
    sleep 5
    systemctl reboot
}

cmd_status() {
    if in_capture_boot; then echo "Boot de capture : OUI"; else echo "Boot de capture : non (démarrage normal)"; fi
    echo "Modules NVIDIA chargés :"; lsmod | grep -E '^nvidia' || echo "  aucun"
    echo "Traceur actuel : $(cat $TRACING/current_tracer)"
}

dump_vbios() {
    local rom="/sys/bus/pci/devices/$GPU_PCI/rom"
    [[ -e $rom ]] || { echo "pas de ROM exposée" > "$OUT/vbios.txt"; return; }
    echo 1 > "$rom"
    cat "$rom" > "$OUT/vbios.rom" 2>/dev/null || echo "lecture ROM impossible" > "$OUT/vbios.txt"
    echo 0 > "$rom"
}

unload_nvidia() {
    # Démarrage UKI : pas d'entrée de boot à modifier, on décharge donc le pilote à chaud.
    log "Arrêt de la session graphique et déchargement du pilote NVIDIA"
    systemctl isolate multi-user.target
    systemctl stop nvidia-persistenced 2>/dev/null || true
    sleep 3
    # nvidia_drm fbdev=1 tient la console texte : on détache fbcon avant rmmod.
    for v in /sys/class/vtconsole/vtcon*/bind; do echo 0 > "$v" 2>/dev/null || true; done
    local m
    for m in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do
        if lsmod | grep -q "^$m "; then
            rmmod "$m" || die "impossible de décharger $m (encore utilisé ?). « sudo systemctl reboot » pour revenir à la normale."
        fi
    done
}

cmd_run() {
    if lsmod | grep -q '^nvidia'; then
        in_capture_boot && die "module NVIDIA chargé dans le boot de capture, inattendu."
        unload_nvidia
    fi

    OUT="$OUT_BASE/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$OUT"
    log "Sortie : $OUT"

    # Infos système (avant le pilote)
    uname -a > "$OUT/uname.txt"
    pacman -Q nvidia-580xx-dkms nvidia-580xx-utils > "$OUT/versions.txt"
    lspci -vvv -nn -s "$GPU_PCI" > "$OUT/lspci.txt"
    dump_vbios

    # mmiotrace : le noyau met tous les CPU sauf un hors ligne pendant la trace.
    log "Activation de mmiotrace"
    echo nop > "$TRACING/current_tracer"
    echo 131072 > "$TRACING/buffer_size_kb"
    echo mmiotrace > "$TRACING/current_tracer"
    cat "$TRACING/trace_pipe" > "$OUT/mmiotrace.txt" &
    local reader=$!

    mark "S1 modprobe nvidia"
    modprobe nvidia
    modprobe nvidia_uvm
    mark "S2 modprobe nvidia_drm (KMS)"
    modprobe nvidia_drm
    mark "S3 init GPU (premier nvidia-smi : chargement des micrologiciels)"
    nvidia-smi > "$OUT/nvidia-smi-init.txt"
    mark "S4 persistence on"
    nvidia-smi -pm 1 >> "$OUT/scenarios.log"

    local clocks gr_min gr_max
    clocks="$(nvidia-smi --query-supported-clocks=gr --format=csv,noheader,nounits | sort -n | uniq)"
    gr_min="$(head -n1 <<<"$clocks")"; gr_max="$(tail -n1 <<<"$clocks")"
    echo "$clocks" > "$OUT/supported-gr-clocks.txt"

    mark "S5 lock gr clock MIN $gr_min"
    nvidia-smi -lgc "$gr_min,$gr_min" >> "$OUT/scenarios.log" 2>&1 || true
    nvidia-smi -q -d CLOCK,PERFORMANCE > "$OUT/state-min.txt"
    mark "S6 lock gr clock MAX $gr_max"
    nvidia-smi -lgc "$gr_max,$gr_max" >> "$OUT/scenarios.log" 2>&1 || true
    nvidia-smi -q -d CLOCK,PERFORMANCE > "$OUT/state-max.txt"
    mark "S7 reset gr clocks"
    nvidia-smi -rgc >> "$OUT/scenarios.log" 2>&1 || true

    local pl_min pl_def
    pl_min="$(nvidia-smi --query-gpu=power.min_limit --format=csv,noheader,nounits | cut -d. -f1)"
    pl_def="$(nvidia-smi --query-gpu=power.default_limit --format=csv,noheader,nounits | cut -d. -f1)"
    mark "S8 power limit MIN $pl_min W"
    nvidia-smi -pl "$pl_min" >> "$OUT/scenarios.log" 2>&1 || true
    mark "S9 power limit DEFAULT $pl_def W"
    nvidia-smi -pl "$pl_def" >> "$OUT/scenarios.log" 2>&1 || true

    # S11 : charge GPU réelle (OpenCL). Sur GeForce Pascal, c'est le seul moyen
    # de déclencher une vraie montée en fréquence (P8 -> P0), que -lgc refuse.
    # gpu_load est compilé dans le home de l'utilisateur ; root le cherche via $SUDO_USER.
    local user_home LOAD
    user_home="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
    LOAD="$user_home/gameos/re/gpu_load"
    if [[ -x $LOAD ]]; then
        # Échantillonne la fréquence graphique toutes les ~0,3 s en tâche de fond,
        # chaque ligne horodatée pour la corréler ensuite aux écritures PMU.
        ( while :; do
              echo "$(date +%s.%N) $(nvidia-smi --query-gpu=clocks.gr,clocks.mem,power.draw,pstate --format=csv,noheader,nounits)"
              sleep 0.3
          done ) > "$OUT/clocks-timeline.txt" &
        local sampler=$!
        mark "S11 GPU load start (ramp up attendu)"
        "$LOAD" 15 >> "$OUT/scenarios.log" 2>&1 || echo "gpu_load a échoué" >> "$OUT/scenarios.log"
        mark "S12 GPU load end (ramp down attendu)"
        sleep 5   # laisse le PMU redescendre en fréquence, tracé
        kill "$sampler" 2>/dev/null || true
    else
        echo "gpu_load absent ($LOAD) : scénario de charge sauté" | tee -a "$OUT/scenarios.log"
    fi

    mark "S10 idle 10 s (activité PMU de fond)"
    sleep 10
    mark "END"

    log "Arrêt de la trace"
    # Le lecteur de trace_pipe doit être arrêté AVANT de changer de traceur (sinon EBUSY).
    kill "$reader" 2>/dev/null || true
    wait "$reader" 2>/dev/null || true
    echo nop > "$TRACING/current_tracer"

    nvidia-smi -q > "$OUT/nvidia-smi-q.txt"
    dmesg > "$OUT/dmesg.txt"
    grep -i 'mmiotrace' "$OUT/dmesg.txt" > "$OUT/mmiotrace-dmesg.txt" || true
    if grep -qi 'lost' "$OUT/mmiotrace-dmesg.txt"; then
        echo "ATTENTION : des événements ont été perdus (voir mmiotrace-dmesg.txt)." | tee -a "$OUT/scenarios.log"
    fi

    log "Compression"
    zstd -q --rm -T0 -19 "$OUT/mmiotrace.txt"
    chmod -R a+rX "$OUT"
    ls -lh "$OUT"
    log "Terminé. « sudo reboot » pour revenir au démarrage normal."
}

case "${1:-}" in
    prepare) cmd_prepare ;;
    run)     cmd_run ;;
    status)  cmd_status ;;
    *) echo "Usage : $0 {prepare|run|status}" >&2; exit 1 ;;
esac
