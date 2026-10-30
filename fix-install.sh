#!/usr/bin/env bash
# Répare une install GameOS interrompue par le conflit lib32-nvidia-utils
# (pile officielle) vs lib32-nvidia-580xx-utils. À lancer depuis l'ISO, en root,
# avec le disque cible encore monté sur /mnt.
#   curl -L https://raw.githubusercontent.com/hklbertrand-lab/GameosGtx/main/fix-install.sh | bash
set +e
[[ -d /mnt/opt/gameos/repo ]] || { echo "ERREUR: /mnt non monté ou dépôt local absent. Remonte: mount /dev/XXXp2 /mnt && mount /dev/XXXp1 /mnt/boot"; exit 1; }

echo "==> Retrait des libs NVIDIA mainline en conflit"
for p in lib32-nvidia-utils nvidia-utils; do
    arch-chroot /mnt pacman -Rdd --noconfirm "$p" 2>/dev/null
done

echo "==> Installation du pilote 580xx (dépôt local)"
arch-chroot /mnt pacman -U --noconfirm --needed /opt/gameos/repo/*.pkg.tar.zst || {
    echo "ECHEC install 580xx — colle la sortie"; exit 1; }

echo "==> Reprise de post-install (KMS + session + autologin)"
arch-chroot /mnt env LOCAL_REPO=/opt/gameos/repo /root/post-install.sh hklbertrand || {
    echo "ECHEC post-install — colle la sortie"; exit 1; }

echo
echo "====================================================="
echo " OK. Install terminée. Tape :  reboot"
echo "====================================================="
