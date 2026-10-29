#!/usr/bin/env bash
# Construit l'ISO GameOS : archiso « releng » + paquets AUR précompilés
# (pilote NVIDIA 580xx, gamescope-session) + post-install.sh embarqué.
# À lancer sur Arch Linux (ou un conteneur Arch), en utilisateur normal avec sudo.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/tmp/gameos-build}"
OUT="${OUT:-$HERE/out}"
PROFILE="$WORK/profile"
REPO="$PROFILE/airootfs/opt/gameos/repo"

# Noms des dépôts AUR (pkgbase) : nvidia-580xx-utils produit aussi nvidia-580xx-dkms.
AUR_PKGS=(nvidia-580xx-utils lib32-nvidia-580xx-utils
          gamescope-session-git gamescope-session-steam-git)

[[ $EUID -ne 0 ]] || { echo "Lance en utilisateur normal (makepkg refuse root)." >&2; exit 1; }
sudo pacman -S --needed --noconfirm archiso base-devel git

rm -rf "$WORK"; mkdir -p "$WORK/aur"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# 1. Paquets AUR -> dépôt local embarqué dans l'ISO (/opt/gameos/repo)
mkdir -p "$REPO"
for pkg in "${AUR_PKGS[@]}"; do
    git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$WORK/aur/$pkg"
    # -s : dépendances installées sur l'hôte (lib32-*, etc.), nécessaire à la compilation
    (cd "$WORK/aur/$pkg" && makepkg -s --noconfirm --needed)
    cp "$WORK/aur/$pkg"/*.pkg.tar.zst "$REPO/"
done
repo-add "$REPO/gameos.db.tar.gz" "$REPO"/*.pkg.tar.zst

# 2. Overlay GameOS
cp -r "$HERE/profile/airootfs/." "$PROFILE/airootfs/"
install -Dm755 "$HERE/post-install.sh" "$PROFILE/airootfs/root/post-install.sh"
cat "$HERE/profile/packages.extra" >> "$PROFILE/packages.x86_64"
sed -i 's/^iso_name=.*/iso_name="gameos"/; s/^iso_label=.*/iso_label="GAMEOS_$(date +%Y%m)"/' \
    "$PROFILE/profiledef.sh"
cat >> "$PROFILE/profiledef.sh" <<'EOF'
file_permissions+=(["/root/post-install.sh"]="0:0:755")
EOF
# multilib pour construire l'ISO
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$PROFILE/pacman.conf"

sudo mkarchiso -v -w "$WORK/iso" -o "$OUT" "$PROFILE"
echo "ISO prête dans $OUT"
