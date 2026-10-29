# Rétro-ingénierie PMU — étape 1 : captures mmiotrace

Objectif : enregistrer tous les accès MMIO du pilote NVIDIA 580 pendant l'initialisation de la GTX 1080 Ti (chargement des micrologiciels, PMU compris) et pendant des changements de fréquence et de limite de puissance. Ces traces servent ensuite, sur ce PC, à extraire le micrologiciel PMU signé (étape 2).

## Installation (une seule fois, sur la machine Arch)
```bash
sudo install -o root -g root -m 755 ~/gameos/re/capture.sh /usr/local/sbin/gameos-capture
echo 'hklbertrand ALL=(root) NOPASSWD: /usr/local/sbin/gameos-capture, /usr/bin/systemctl reboot' | sudo tee /etc/sudoers.d/50-gameos-capture
sudo chmod 440 /etc/sudoers.d/50-gameos-capture
sudo visudo -c
```
Le script est installé hors de ton dossier personnel et appartient à root : la règle sudo sans mot de passe ne vaut que pour lui et pour le redémarrage.

## Déroulement d'une capture
1. `sudo gameos-capture run` (environ 1 minute) : coupe la session Steam, décharge le pilote NVIDIA à chaud, puis trace son rechargement. La TV passe en noir ou en console texte, c'est normal. Pendant la trace, un seul cœur CPU reste actif.
   (Ta machine démarre en UKI, donc `prepare`, qui sert à créer une entrée de démarrage dédiée, ne s'applique pas.)
3. `sudo systemctl reboot` : retour au démarrage normal dans Steam.
4. Rapatriement des traces sur Windows :
   ```bash
   scp -r hklbertrand@192.168.1.104:/var/lib/gameos-re E:\antigravity\gameos\re\captures
   ```

## Scénarios enregistrés
Chaque scénario est délimité dans `mmiotrace.txt.zst` par une ligne `MARK ... GAMEOS Sx`.

| Marqueur | Action |
|---|---|
| S1 | `modprobe nvidia` |
| S2 | `modprobe nvidia_drm` (KMS) |
| S3 | premier `nvidia-smi` : initialisation du GPU, chargement des micrologiciels |
| S4 | mode persistance |
| S5 / S6 / S7 | fréquence graphique bloquée au minimum, puis au maximum, puis libérée |
| S8 / S9 | limite de puissance minimale, puis par défaut |
| S10 | 10 s au repos (activité de fond du PMU) |

Fichiers annexes : `vbios.rom` (tables de performances et de tensions), `lspci.txt`, `nvidia-smi-*.txt`, `state-min/max.txt`, `dmesg.txt`, `scenarios.log`.

## Si ça se passe mal
- **« événements perdus » dans scenarios.log** : la trace est incomplète. Relancer prepare puis run. Si ça se répète, augmenter `buffer_size_kb` dans le script.
- **La machine ne répond plus** : appui long sur le bouton d'alimentation. L'entrée de capture n'est programmée qu'une fois, donc le redémarrage suivant revient au mode normal.
