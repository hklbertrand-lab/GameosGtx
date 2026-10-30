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

### B. ISO maison + installeur automatique (install définitive propre)
Construire l'ISO sur une machine Arch (ou conteneur `archlinux`). WSL2 ne convient pas : mkarchiso a besoin des loop devices.
```bash
./build.sh            # ISO dans out/
```
Flasher l'ISO avec Rufus (mode DD) ou `dd`, démarrer dessus **en UEFI**, puis :
```bash
gameos-install /dev/XXX      # XXX = SSD cible (lsblk -dpo NAME,SIZE,MODEL) — EFFACE TOUT
```
`install.sh` partitionne (GPT : ESP 1 Gio + root ext4), installe une Arch propre, pose systemd-boot, demande les mots de passe root/utilisateur, puis lance `post-install.sh` avec le dépôt local embarqué — **aucune compilation AUR, aucune étape manuelle**. Au `reboot`, la machine démarre direct dans Steam en 1440p@120 + HDR.

Réglages par défaut en tête d'`install.sh` : utilisateur `hklbertrand`, clavier `fr`, locale `en_US.UTF-8`, fuseau `Europe/Paris`, noyau `linux-zen`.

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
- **Saccades** : ajouter `--force-composition` dans `GAMESCOPE_ARGS`.
- **HDR** : fonctionne (gamescope l'active depuis l'EDID, BT2020/ST2084) en 1440p@120 ou 1080p. Il noircit l'écran en 4K@60 (10-bit trop juste sur HDMI 2.0) : ne pas forcer le HDR au-dessus de 1440p.
- **Mise à jour du noyau** : DKMS recompile le module automatiquement. Ne jamais retirer `IgnorePkg` : le pilote 590+ ne démarre pas sur la 1080 Ti.
- **Veille / réveil manette** : la veille système est **désactivée** (`suspend.target` masqué + `logind IdleAction=ignore`). Raison : une manette sans fil (Xbox 360…) ne peut pas réveiller depuis la veille (lien radio coupé, pas de re-synchro au récepteur). Le système reste donc allumé et répond tout de suite à la manette. Pour protéger un écran OLED, éteindre la TV (sa dalle) quand on ne joue pas — la console reste prête, la manette la réveille dès que la TV se rallume.
