# GameOS : console « type SteamOS » pour GTX 1080 Ti

Arch Linux qui démarre directement dans Steam Big Picture (interface Steam Deck) sous **gamescope**, avec un bureau KDE de secours.

## Pourquoi pas SteamOS / Nouveau ?
- **SteamOS** ne cible que l'AMD.
- **Nouveau** ne peut pas monter en fréquence sur Pascal, donc les performances sont inutilisables.
- **Les modules NVIDIA « open »** ne gèrent que Turing et les cartes plus récentes.
- **NVIDIA 590+** a abandonné Pascal. La **branche 580** est la dernière qui le gère, et le script la fige avec `IgnorePkg`.

## Deux façons d'installer

### A. Arch déjà installée (le plus simple)
```bash
sudo ./post-install.sh monutilisateur
```

### B. ISO maison
Sur une machine Arch, ou dans un conteneur `archlinux`. WSL2 ne convient pas car mkarchiso a besoin des loop devices.
```bash
./build.sh
```
L'ISO arrive dans `out/`. Flashe-la avec Rufus (mode DD) ou `dd`, démarre dessus, puis suis le message affiché (`/etc/motd`) : archinstall, puis post-install en chroot avec le dépôt local. L'installation ne demande alors aucune compilation AUR.

## Ce que fait post-install.sh
| Étape | Détail |
|---|---|
| Pilote | `nvidia-580xx-dkms` / `-utils` / `lib32-` (AUR), nouveau blacklisté, `IgnorePkg` |
| KMS | `nvidia-drm.modeset=1 fbdev=1` (cmdline GRUB ou systemd-boot, et modprobe), modules dans l'initramfs |
| Gaming | steam, gamescope, mangohud, gamemode, pipewire, Vulkan 32 et 64 bits |
| Session | `gamescope-session-plus` + `gamescope-session-steam`, autologin SDDM (Wayland) |
| Réglages | `~/.config/environment.d/gamescope-session-plus.conf` (résolution, fréquences, adaptive-sync) |
| Bureau | KDE Plasma, accessible depuis Steam : Alimentation, puis Passer au bureau |

Options : `NO_AUTOLOGIN=1` pour garder l'écran de connexion, `LOCAL_REPO=dossier` pour utiliser des paquets déjà construits.

## Vérifications après redémarrage
```bash
nvidia-smi                                         # 580.xx
cat /sys/module/nvidia_drm/parameters/modeset      # Y
journalctl --user -b -u gamescope-session-plus@steam
```

## Dépannage
- **Écran noir au démarrage** : depuis un TTY (Ctrl+Alt+F3), vérifier `modeset=Y` et lancer `gamescope -- steam -gamepadui` à la main pour lire l'erreur.
- **Résolution ou fréquence incorrecte** : modifier `SCREEN_WIDTH`, `SCREEN_HEIGHT` et `CUSTOM_REFRESH_RATES` dans `environment.d`.
- **Saccades** : ajouter `--force-composition` dans `GAMESCOPE_ARGS`. Le HDR n'est pas disponible sur Pascal.
- **Mise à jour du noyau** : DKMS recompile le module automatiquement. Ne jamais retirer `IgnorePkg` : le pilote 590+ ne démarre pas sur la 1080 Ti.
