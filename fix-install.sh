#!/usr/bin/env bash
# Répare une install GameOS interrompue :
#  - conflit lib32-nvidia-utils (pile officielle) vs lib32-nvidia-580xx-utils ;
#  - 'target not found: nvidia' (boucle de retrait non tolérante, set -e) ;
#  - erreur DKMS arch1 (linux-headers plain inutile).
# À lancer depuis l'ISO, en root, disque cible monté sur /mnt.
#   curl -L https://raw.githubusercontent.com/hklbertrand-lab/GameosGtx/main/fix-install.sh | bash
set +e
[[ -d /mnt/opt/gameos/repo ]] || { echo "ERREUR: /mnt non monté ou dépôt local absent."; exit 1; }
PI=/mnt/root/post-install.sh

echo "==> Patch du post-install (retrait tolérant + sans linux-headers)"
sed -i 's@if pacman -Q "\$p" &>/dev/null; then pacman -Rdd --noconfirm "\$p"; fi@pacman -Rdd --noconfirm "$p" 2>/dev/null || true@' "$PI"
sed -i 's@ linux-zen-headers linux-headers @ linux-zen-headers @' "$PI"

echo "==> Retrait des libs NVIDIA mainline en conflit"
for p in lib32-nvidia-utils nvidia-utils; do
    arch-chroot /mnt pacman -Rdd --noconfirm "$p" 2>/dev/null
done

echo "==> Installation du pilote 580xx (dépôt local)"
arch-chroot /mnt pacman -U --noconfirm --needed /opt/gameos/repo/*.pkg.tar.zst || {
    echo "ECHEC install 580xx — colle la sortie"; exit 1; }

echo "==> Reprise de post-install (KMS + session + autologin)"
if arch-chroot /mnt env LOCAL_REPO=/opt/gameos/repo /root/post-install.sh hklbertrand; then
    echo; echo "====================================================="
    echo " OK. Install terminée. Tape :  reboot"
    echo "====================================================="
else
    echo "ECHEC post-install — colle la sortie"; exit 1
fi
