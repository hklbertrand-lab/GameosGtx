# CEC-Pico — adaptateur HDMI-CEC → clavier USB pour GameOS

Piloter GameOS (Steam Big Picture) avec la **télécommande de la TV**, sans Pulse-Eight.
Un **Raspberry Pi Pico / RP2350** lit le bus HDMI-CEC et se présente à la console comme un
**clavier USB HID** : les touches de la télécommande deviennent flèches / Entrée / Échap.
**Zéro logiciel à installer côté GameOS** — l'OS voit un clavier, Steam navigue.

Base firmware : [**Pico-CEC** de gkoh](https://github.com/gkoh/pico-cec) (CMake + Pico SDK,
MIT). Recette ci-dessous **testée** : build RP2350 OK, keymap ajustée pour Steam.

## Matériel
| Pièce | Rôle | ~Prix |
|---|---|---|
| **RP2350-Zero** (Waveshare) *ou* **Pi Pico H** (RP2040) | MCU + USB natif | 5–13 € |
| **Breakout HDMI mâle→femelle 19 broches** (pas 2,54 mm) | tirer CEC/DDC sans couper le câble | 4–8 € |
| 4 fils + soudure | relier les 4 broches | — |

**Pas de résistance.** Pico-CEC émule l'open-drain en basculant le GPIO entrée/sortie et
s'appuie sur le pull-up déjà présent sur le bus CEC (côté TV/source). 3.3 V des deux côtés,
aucun level shifter.

## Câblage (4 fils, full-size HDMI)
Pico-CEC utilise le CEC **et** le bus DDC (I²C, pour lire l'EDID). Quatre connexions directes :

| Broche HDMI | RP2350-Zero / Pico (cible `pico2` ou `pico`) |
|---|---|
| **13 — CEC** | **GP3** (`CEC_PIN`, défaut) |
| **15 — DDC clock** | **GP5** (SCL, `PICO_DEFAULT_I2C_SCL_PIN`) |
| **16 — DDC data** | **GP4** (SDA, `PICO_DEFAULT_I2C_SDA_PIN`) |
| **17 — masse** | **GND** |

Toutes ces pastilles sont sur le **bord** du RP2350-Zero. Le câble HDMI de la TV **traverse**
le breakout (vidéo/audio intacts) ; le Pico se branche en **USB sur la console**.
⚠️ Connecteur **mini-HDMI** : le CEC n'est pas la 13 — vérifier le brochage.

## Build (testé sur Arch)
Dépendances : `cmake`, `arm-none-eabi-gcc`, `arm-none-eabi-newlib` (+ `git`, `python3`).
```bash
sudo pacman -S --needed cmake arm-none-eabi-gcc arm-none-eabi-newlib
git clone --recurse-submodules https://github.com/gkoh/pico-cec
cd pico-cec
# Adapter la touche "retour" pour Steam Big Picture (Backspace -> Échap) :
sed -i 's/\[CEC_USER_EXIT\] = HID_KEY_BACKSPACE/[CEC_USER_EXIT] = HID_KEY_ESCAPE/' src/cec-config.c
# RP2350-Zero (Pico 2) ; pour un Pi Pico RP2040 : -DPICO_BOARD=pico
cmake -S . -B build -DPICO_BOARD=pico2 -DCEC_PIN=3 -DCEC_OSD_NAME="GameOS"
cmake --build build
# -> build/pico-cec.uf2
```
RP2040 et RP2350 produisent des `.uf2` **incompatibles** : builder pour la carte réelle
(`rm -rf build` entre deux cibles). Options : `PICO_BOARD`, `CEC_PIN`, `CEC_OSD_NAME`.

## Keymap (CEC → touches HID, adaptée Steam)
`src/cec-config.c` : Haut/Bas/Gauche/Droite → flèches, **Select → Entrée**, **Exit → Échap**
(patch ci-dessus ; Kodi par défaut = Backspace), Pause → Espace, chiffres → 0-9. Flèches +
Entrée + Échap = tout ce que Steam Big Picture demande.

## Flasher
Maintenir **BOOTSEL**, brancher l'USB → la carte monte en lecteur ; **glisser le `.uf2`**.
Elle redémarre en clavier HID.

## Test sur GameOS
`lsusb` montre un clavier ; les flèches de la **télécommande TV** naviguent dans Steam.
(GameOS a `cec-ctl` installé mais cette approche HID ne l'utilise pas.)

## Portée et limites
- ✅ **Télécommande → navigation Steam** : objectif atteint, sans config.
- ❌ **Synchro allumage/extinction** TV↔console (vraie pile `libcec` bidirectionnelle) : non
  couverte par l'approche HID ; il faudrait émuler un Pulse-Eight (protocole USB P8).
- La **LED RGB (WS2812)** du RP2350-Zero ne sert pas de voyant d'état avec la cible `pico2`
  générique — sans impact.

## Sources
- Pico-CEC : https://github.com/gkoh/pico-cec
- Write-up matériel : https://www.hackster.io/guorongkoh/pico-cec-hdmi-cec-to-usb-keyboard-adapter-6d18f9
