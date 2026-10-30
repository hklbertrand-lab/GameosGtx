#!/usr/bin/env bash
# GameOS post-install : transforme une Arch Linux fraîchement installée en
# console « type SteamOS » (Steam Big Picture sous gamescope) pour GPU NVIDIA
# Pascal (GTX 10xx, ex. 1080 Ti) avec la branche pilote 580xx figée.
#
# Usage (en root) :  ./post-install.sh <utilisateur>
# Variables :        LOCAL_REPO=/chemin  -> utilise des paquets AUR déjà construits
#                    NO_AUTOLOGIN=1      -> ne configure pas SDDM en autologin
set -euo pipefail

USER_NAME="${1:-}"
[[ $EUID -eq 0 ]] || { echo "À lancer en root." >&2; exit 1; }
[[ -n "$USER_NAME" ]] && id "$USER_NAME" &>/dev/null || {
    echo "Usage : $0 <utilisateur existant>" >&2; exit 1; }
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

# Noms des dépôts AUR (pkgbase) : nvidia-580xx-utils produit aussi nvidia-580xx-dkms.
AUR_PKGS=(nvidia-580xx-utils lib32-nvidia-580xx-utils
          gamescope-session-git gamescope-session-steam-git)
NVIDIA_IGNORE="nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils"

log() { printf '\n\e[1;32m==> %s\e[0m\n' "$*"; }

# ---------------------------------------------------------------- multilib
log "Activation de [multilib]"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

# ---------------------------------------------- pilote figé sur la branche 580
log "Gel du pilote NVIDIA 580xx (dernière branche supportant Pascal)"
if grep -q '^IgnorePkg' /etc/pacman.conf; then
    grep -q 'nvidia-580xx-dkms' /etc/pacman.conf ||
        sed -i "s/^IgnorePkg *=.*/& $NVIDIA_IGNORE/" /etc/pacman.conf
else
    sed -i "/^\[options\]/a IgnorePkg = $NVIDIA_IGNORE" /etc/pacman.conf
fi

# --------------------------------------------------------- paquets officiels
log "Installation de la pile gaming"
# Retire un éventuel pilote nvidia récent (590+ ne gère plus Pascal) ou open.
for p in nvidia nvidia-open nvidia-dkms nvidia-open-dkms nvidia-utils lib32-nvidia-utils; do
    if pacman -Q "$p" &>/dev/null; then pacman -Rdd --noconfirm "$p"; fi
done
pacman -Syu --noconfirm --needed \
    base-devel git dkms linux-zen linux-zen-headers linux-headers \
    steam gamescope mangohud lib32-mangohud gamemode lib32-gamemode \
    vulkan-icd-loader lib32-vulkan-icd-loader egl-wayland \
    pipewire pipewire-pulse pipewire-alsa lib32-pipewire wireplumber \
    plasma-meta sddm konsole dolphin networkmanager bluez bluez-utils \
    xdg-desktop-portal-kde ttf-liberation

# --------------------------------------------------------------- paquets AUR
log "Installation des paquets AUR (${AUR_PKGS[*]})"
if [[ -n "${LOCAL_REPO:-}" && -d "$LOCAL_REPO" ]]; then
    # La pile officielle (steam, lib32-*) tire les utils NVIDIA MAINLINE
    # (lib32-nvidia-utils / nvidia-utils) via le provider nvidia-libgl ; ils
    # entrent en conflit avec les 580xx. On les retire juste avant d'installer
    # les 580xx (qui fournissent le même libgl) -> plus de conflit non résolu.
    # Retrait paquet par paquet : un -Rdd groupé échoue en entier si l'un des
    # deux n'est pas installé, laissant l'autre en place (et le conflit).
    for p in lib32-nvidia-utils nvidia-utils; do
        pacman -Rdd --noconfirm "$p" 2>/dev/null || true
    done
    pacman -U --noconfirm --needed "$LOCAL_REPO"/*.pkg.tar.zst
else
    BUILD_DIR="$(sudo -u "$USER_NAME" mktemp -d)"
    # makepkg refuse root : on construit en tant qu'utilisateur.
    echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/99-gameos-build
    for pkg in "${AUR_PKGS[@]}"; do
        sudo -u "$USER_NAME" git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$BUILD_DIR/$pkg"
        (cd "$BUILD_DIR/$pkg" && sudo -u "$USER_NAME" makepkg -si --noconfirm --needed)
    done
    rm -f /etc/sudoers.d/99-gameos-build
    rm -rf "$BUILD_DIR"
fi

# ------------------------------------------------------- KMS NVIDIA (gamescope)
log "Configuration DRM/KMS NVIDIA"
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
# kms hook charge nouveau : on l'enlève pour éviter un conflit.
sed -i 's/\(^HOOKS=.*\) kms/\1/' /etc/mkinitcpio.conf
cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

CMDLINE="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"
# systemd-boot d'abord : /etc/default/grub peut exister sans que GRUB soit utilisé.
if [[ -d /boot/loader/entries ]]; then
    for e in /boot/loader/entries/*.conf; do
        grep -q 'nvidia-drm.modeset' "$e" || sed -i "s/^options .*/& $CMDLINE/" "$e"
    done
elif [[ -f /etc/default/grub ]]; then
    grep -q 'nvidia-drm.modeset' /etc/default/grub ||
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/&$CMDLINE /" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "Chargeur inconnu : ajoute manuellement « $CMDLINE » à la ligne de commande noyau." >&2
fi

systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
mkinitcpio -P

# ------------------------------------------------------ session gamescope
log "Session Steam (gamescope-session-plus)"
ENV_DIR="$USER_HOME/.config/environment.d"
# install -d ne donne le propriétaire qu'au dernier dossier : ~/.config doit aussi appartenir à l'utilisateur.
install -d -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.config" "$ENV_DIR"
cat > "$ENV_DIR/gamescope-session-plus.conf" <<'EOF'
# Lu par gamescope-session-plus. Sortie 1440p@120 sur la TV (HDMI 2.0).
SCREEN_WIDTH=2560
SCREEN_HEIGHT=1440
CUSTOM_REFRESH_RATES=60,120,144
# Options supplémentaires passées à gamescope :
GAMESCOPE_ARGS=--adaptive-sync
# NVIDIA : Vulkan WSI via la couche gamescope
ENABLE_GAMESCOPE_WSI=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
# HDR : gamescope l'active depuis l'EDID de la TV (BT2020/ST2084) et ça marche
# en 1440p@120. Les deux flags à 0 empêchent Steam de FORCER le HDR en 4K@60,
# seul cas qui noircit l'écran (10-bit trop juste sur HDMI 2.0). Ne pas les passer
# à 1 sans repasser d'abord en-dessous de 4K.
STEAM_GAMESCOPE_HDR_SUPPORTED=0
ENABLE_GAMESCOPE_HDR=0
EOF
chown "$USER_NAME:$USER_NAME" "$ENV_DIR/gamescope-session-plus.conf"
usermod -aG video,input,gamemode "$USER_NAME" 2>/dev/null || usermod -aG video,input "$USER_NAME"

if [[ -z "${NO_AUTOLOGIN:-}" ]]; then
    SESSION="$(basename "$(ls /usr/share/wayland-sessions/gamescope-session-steam*.desktop 2>/dev/null | head -n1)" .desktop)"
    [[ -n "$SESSION" ]] || SESSION=gamescope-session-steam
    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/10-gameos-autologin.conf <<EOF
[Autologin]
User=$USER_NAME
Session=$SESSION
Relogin=true

[General]
DisplayServer=wayland
EOF
fi

# ------------------------------------------------- jamais de veille système
# Les manettes sans fil (ex. Xbox 360) ne peuvent pas réveiller depuis la veille
# (le lien radio est coupé, la manette ne se re-synchronise pas au récepteur).
# On interdit donc toute suspension : le système reste allumé, le récepteur à
# l'écoute, et une pression manette répond instantanément. Écran : voir README
# (extinction gérée par la TV / son économiseur sur OLED).
log "Désactivation de la veille système (réveil manette fiable)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
install -d /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-gameos-nosuspend.conf <<'EOF'
[Login]
IdleAction=ignore
HandleSuspendKey=ignore
HandleLidSwitch=ignore
HandleHibernateKey=ignore
HandlePowerKey=poweroff
EOF

systemctl enable sddm NetworkManager bluetooth

log "Terminé. Redémarre : la machine démarrera directement dans Steam (mode Deck)."
echo "Bureau KDE : Steam > Alimentation > Passer au bureau."
