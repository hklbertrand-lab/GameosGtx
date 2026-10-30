# CEC-Pico — adaptateur HDMI-CEC → clavier USB pour GameOS

Piloter GameOS (Steam Big Picture) avec la **télécommande de la TV**, sans Pulse-Eight.
Un **Raspberry Pi Pico** lit le bus HDMI-CEC et se présente à la console comme un
**clavier USB HID** : les touches de la télécommande deviennent des flèches / Entrée /
Échap. **Zéro logiciel à installer côté GameOS** — l'OS voit un clavier, Steam navigue.

Base firmware : [**Pico-CEC** de gkoh](https://github.com/gkoh/pico-cec) (RP2040/RP2350,
CEC → clavier USB, MIT). On ne réécrit pas de pile CEC : elle est délicate (timing) et
déjà éprouvée là.

## Principe
```
TV (HDMI) ──┐
            │  câble HDMI (vidéo inchangée, traverse l'adaptateur)
   [ breakout HDMI mâle→femelle ]
      │ broche 13 = CEC ──────────► GP3  (Pico)
      │ broche 17 = masse ────────► GND  (Pico)
            │
   Pico ── USB ──► console GameOS   (vu comme un clavier)
```
Le CEC est un bus **1 fil, 3.3 V, open-drain, ~400 bit/s**. Le GPIO du Pico est en 3.3 V :
**connexion directe, aucun level shifter**. On ne touche jamais aux paires vidéo TMDS.

## BOM (~10 €)
| Pièce | Rôle | Prix indicatif |
|---|---|---|
| Raspberry Pi **Pico** (RP2040) | MCU + USB natif | ~4 € |
| **Breakout HDMI mâle→femelle** (ou adaptateur pass-through à broches) | tirer CEC (13) + masse (17) sans couper le câble | ~5 € |
| 2 fils Dupont | GP3 ↔ CEC, GND ↔ masse | — |
| (option) résistance série ~27–47 Ω sur la ligne CEC | protection GPIO | — |
| (option) boîtier imprimé 3D | finition | — |

> Variante compacte : un **Seeed XIAO RP2040** + adaptateur HDMI pass-through (c'est le
> montage du write-up Hackster). Même câblage, plus petit.

## Câblage (full-size HDMI)
- **Broche 13 (CEC)** → **GP3** du Pico (défaut `CEC_PIN`, changeable au build via `-DCEC_PIN`).
- **Broche 17 (masse DDC/CEC)** → **GND** du Pico (masse commune avec la TV, indispensable).
- Le reste du câble HDMI **traverse** l'adaptateur sans modification (vidéo + audio intacts).
- ⚠️ Connecteur **mini-HDMI** : la broche CEC n'est pas la 13 (≈ 14) — vérifier le brochage.
  Le schéma exact (et d'éventuelles lignes DDC utilisées pour la détection) est dans le dépôt
  Pico-CEC.

## Firmware
1. Récupérer Pico-CEC : `git clone https://github.com/gkoh/pico-cec`
2. Construire (PlatformIO) ou prendre l'**UF2** d'une *release*.
   - CEC par défaut sur **GP3** ; pour un autre GPIO : `-DCEC_PIN=<n>` au build.
3. Flasher : brancher le Pico en maintenant **BOOTSEL**, il monte en lecteur USB, **glisser
   l'UF2** dessus. Il redémarre en clavier HID.

## Mapping télécommande → Steam Big Picture
Steam BPM se pilote au clavier : **flèches** = navigation, **Entrée** = valider, **Échap** =
retour. Table CEC (codes *User Control*) → touches à viser :

| Télécommande (CEC) | Touche HID | Action Steam |
|---|---|---|
| Haut / Bas / Gauche / Droite | ↑ ↓ ← → | naviguer |
| Select / OK | Entrée | valider |
| Back / Exit | Échap | retour |
| Play/Pause | Espace | lecture/pause |
| (option) Home/Root Menu | — | libre (ex. ouvrir l'UI Steam) |

Pico-CEC cible Kodi par défaut : il suffit d'**ajuster sa table de correspondance** vers ces
touches-là (fichier de keymap du projet) puis de reconstruire. Steam ne demande rien de plus
que flèches/Entrée/Échap.

## Test sur GameOS
1. Brancher le Pico en USB sur la console, câble TV via le breakout.
2. `lsusb` doit montrer un clavier ; `cat /proc/bus/input/devices` une nouvelle entrée clavier.
3. Appuyer sur les flèches de la **télécommande TV** → le curseur bouge dans Steam.
4. (GameOS a déjà `cec-ctl` installé, mais cette approche HID **ne l'utilise pas**.)

## Portée et limites (honnête)
- ✅ **Télécommande → console** (navigation Steam) : c'est l'objectif, et ça marche sans config.
- ❌ **Synchro d'allumage/extinction** TV↔console (vraie pile CEC bidirectionnelle, `libcec`) :
  non couverte par l'approche HID. Il faudrait alors émuler un Pulse-Eight (protocole USB P8),
  bien plus lourd.
- Un **Pulse-Eight** du commerce (~40 €) reste l'option « ça marche tout de suite avec libcec »
  si tu veux le CEC complet ; le Pico (~10 €) est le bon compromis pour **naviguer à la
  télécommande**.

## Sources
- Pico-CEC (code + schéma) : https://github.com/gkoh/pico-cec
- Write-up matériel (XIAO RP2040 + pass-through) : https://www.hackster.io/guorongkoh/pico-cec-hdmi-cec-to-usb-keyboard-adapter-6d18f9
