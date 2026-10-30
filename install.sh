#!/usr/bin/env bash
# GameOS — installeur automatisé (à lancer depuis l'ISO GameOS, en root, UEFI).
# Installe une Arch Linux PROPRE sur le disque cible, configure systemd-boot,
# puis applique post-install.sh (pilote 580xx + Steam/gamescope, depuis le
# dépôt local embarqué -> aucune compilation AUR).
#
#   gameos-install /dev/nvme0n1        # EFFACE TOUT le disque indiqué
#
# Réglages par défaut modifiables ci-dessous (clavier FR, locale en_US, Paris).
set -euo pipefail

# ----------------------------------------------------------------- réglages
HOSTNAME=gameos
USERNAME=hklbertrand
TIMEZONE=Europe/Paris
KEYMAP=us
LOCALE=en_US.UTF-8
KERNEL=linux-zen
REPO_SRC=/opt/gameos/repo                 # dépôt local embarqué dans l'ISO
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { printf '\n\e[1;32m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31mERREUR : %s\e[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "à lancer en root."
[[ -d /sys/firmware/efi ]] || die "démarre l'ISO en mode UEFI (pas BIOS/Legacy)."

# ----------------------------------------------------------- disque cible
DISK="${1:-}"
if [[ -z $DISK ]]; then
    echo "Disques disponibles :"
    lsblk -dpo NAME,SIZE,MODEL,TRAN | grep -viE 'loop|^NAME'
    die "usage : $0 /dev/XXX   (ce disque sera EFFACÉ)"
fi
[[ -b $DISK ]] || die "$DISK n'est pas un périphérique bloc."

echo
lsblk -po NAME,SIZE,MODEL,MOUNTPOINTS "$DISK"
echo
echo -e "\e[1;31m*** TOUT LE CONTENU DE $DISK VA ÊTRE DÉTRUIT ***\e[0m"
read -rp "Pour confirmer, retape exactement le chemin du disque : " CONFIRM
[[ "$CONFIRM" == "$DISK" ]] || die "confirmation incorrecte — abandon."

# suffixe de partition : nvme0n1p1 / mmcblk0p1 vs sda1
case "$DISK" in *nvme*|*mmcblk*|*loop*) PP="${DISK}p" ;; *) PP="$DISK" ;; esac
ESP="${PP}1"; ROOTP="${PP}2"

# ----------------------------------------------------------- partitionnement
log "Partitionnement GPT : ESP 1 Gio (FAT32) + root (ext4) sur $DISK"
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
wipefs -a "$DISK"
sgdisk -Z "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI "$DISK"
sgdisk -n2:0:0   -t2:8300 -c2:root "$DISK"
partprobe "$DISK"; sleep 1

log "Formatage"
mkfs.fat -F32 -n EFI "$ESP"
mkfs.ext4 -F -L gameos-root "$ROOTP"

log "Montage"
mount "$ROOTP" /mnt
mkdir -p /mnt/boot
mount "$ESP" /mnt/boot

# ----------------------------------------------------------- système de base
log "Installation du système de base (pacstrap)"
pacstrap -K /mnt base base-devel "$KERNEL" "${KERNEL}-headers" linux-firmware \
    sudo vim git networkmanager efibootmgr intel-ucode amd-ucode

log "fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# DNS dans le chroot (pour le pacman -Syu de post-install)
cp -f /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true

# dépôt local + post-install dans la cible
if [[ -d $REPO_SRC ]]; then
    log "Copie du dépôt local embarqué -> /opt/gameos/repo (pas de compilation AUR)"
    mkdir -p /mnt/opt/gameos/repo
    cp -a "$REPO_SRC"/. /mnt/opt/gameos/repo/
    LOCAL_REPO=/opt/gameos/repo
else
    echo "ATTENTION : dépôt local $REPO_SRC absent -> post-install compilera l'AUR (réseau requis)." >&2
    LOCAL_REPO=""
fi
for src in /root/post-install.sh "$SELF_DIR/post-install.sh"; do
    [[ -f $src ]] && { install -Dm755 "$src" /mnt/root/post-install.sh; break; }
done
[[ -f /mnt/root/post-install.sh ]] || die "post-install.sh introuvable."

# ----------------------------------------------------------- script chroot
# Écrit dans un fichier (pas un heredoc sur stdin) pour garder le terminal
# disponible aux invites de mot de passe.
cat > /mnt/root/gameos-chroot.sh <<CHROOT
#!/usr/bin/env bash
set -euo pipefail
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#\\($LOCALE\\)/\\1/' /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
printf '127.0.0.1 localhost\\n::1 localhost\\n127.0.1.1 $HOSTNAME\\n' > /etc/hosts
systemctl enable NetworkManager

# ---- systemd-boot ----
bootctl install
cat > /boot/loader/loader.conf <<L
default gameos.conf
timeout 1
console-mode max
L
ROOT_UUID=\$(blkid -s UUID -o value "$ROOTP")
cat > /boot/loader/entries/gameos.conf <<E
title   GameOS
linux   /vmlinuz-$KERNEL
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-$KERNEL.img
options root=UUID=\$ROOT_UUID rw
E

# ---- comptes ----
echo; echo ">>> Mot de passe ROOT :"
passwd
id "$USERNAME" &>/dev/null || useradd -m -G wheel "$USERNAME"
echo ">>> Mot de passe de $USERNAME :"
passwd "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ---- GameOS ----
LOCAL_REPO="$LOCAL_REPO" /root/post-install.sh "$USERNAME"
CHROOT
chmod +x /mnt/root/gameos-chroot.sh

log "Configuration dans le chroot (mots de passe à définir)"
arch-chroot /mnt /root/gameos-chroot.sh

# ----------------------------------------------------------- fin
rm -f /mnt/root/gameos-chroot.sh
log "Installation GameOS terminée sur $DISK."
echo "Retire la clé USB, puis :  reboot"
echo "La machine démarrera directement dans Steam (mode Deck), en 1440p@120 + HDR."
