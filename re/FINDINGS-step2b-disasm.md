# Étape 2b (suite) — préparation du désassemblage

## Nature du binaire
`nv-kernel.o_binary` : ELF 64 bits **relogeable**, x86-64, non stripped en apparence. Sections utiles :
| Section | Rôle | Taille |
|---|---|---|
| `.text` | code | ~14,5 Mo |
| `.rodata` | données en lecture seule (micrologiciels embarqués) | ~82 Mo |
| `.data` | données modifiables | ~1,7 Mo |
| `.rela.text` / `.rela.rodata` | relocations = références croisées code→données **exploitables** | — |

## Obstacle : symboles anonymisés
**61 721 symboles sur 62 279 sont renommés `_nvXXXXXXrm`.** Seuls les symboles externes (interface noyau) gardent un nom lisible. On ne peut donc **pas** retrouver le micrologiciel PMU par un nom de symbole. Les chaînes `RmPmuUcodeProfile` / « PMU ucode » sont des clés de registre (réglages d'exécution), pas des noms de symboles.

→ La méthode devient : suivre les **relocations** depuis le code qui référence ces chaînes et les registres PMU (DMEMD0/IMEMD vus dans les captures) jusqu'au symbole de données `_nvXXXXrm` qui contient le micrologiciel.

## Candidats micrologiciels (plus gros objets .rodata/.data)
| Symbole | Taille | Section |
|---|---|---|
| `_nv046226rm` | 94 976 o | .rodata |
| `_nv056765rm` / `_nv056766rm` | 72 448 o | .rodata |
| `_nv029068rm` | 56 424 o | .rodata |
| `_nv046224rm` / `_nv046225rm` | 48 384 o | .rodata |
| groupe `_nv0466xxrm` | 58 000 / 58 292 o | .data |

Un micrologiciel PMU Pascal (IMEM + DMEM) fait typiquement 40–100 Ko : ces objets collent. Les groupes de tailles quasi identiques (58 000 / 72 448) ressemblent à des jeux de micrologiciels Falcon par puce/moteur.

## Outillage
- **Ghidra écarté ici** : ce PC a Java 8 (Ghidra veut Java 17+ 64 bits) et Ghidra n'est pas installé (~700 Mo à télécharger, travail en interface graphique).
- **Sur la machine Arch : seul `objdump` est présent.** Il désassemble et on a les relocations, mais c'est laborieux à la main.
- **Proposition : installer `rizin`** (`sudo pacman -S rizin`), un désassembleur scriptable sans interface, que je pilote directement en SSH. Je pourrais alors : charger le binaire, résoudre les références croisées vers les chaînes PMU, trouver la routine de chargement, et de là le symbole `_nvXXXXrm` du micrologiciel — puis l'extraire par `objcopy`/`dd` et le valider (taille + en-tête) contre le format public `gp102/sec2/`.

## Tri des candidats par leur contenu (premiers octets)
| Symbole | Taille | Contenu observé | Verdict |
|---|---|---|---|
| `_nv046226rm` | 95 Ko | octets aléatoires dès l'offset 0 | **chiffré/signé → candidat fort** |
| `_nv056765rm` / `_nv056766rm` | 72 Ko (×2) | aléatoire dès le début | **chiffré → candidats** |
| `_nv046224rm` / `_nv046225rm` | 48 Ko (×2) | aléatoire dès le début | **chiffré → candidats** |
| `_nv029068rm` | 55 Ko | code x86-64 (`cmp rsi,1`, NOP `0f 1f`) | écarté (code en rodata) |
| groupe `_nv0466xxrm` (.data) | 58 Ko | code x86-64 + relocations (`e8 00000000`) | écarté (code/trampolines) |

Les blocs chiffrés sont les vrais candidats micrologiciel. Les numéros consécutifs `_nv046224/225/226` suggèrent un **jeu lié** (image + signature + descripteur, ou variantes de puce). À comparer : le descripteur SEC2 public GP102 a, lui, un en-tête lisible (date « Mon Jan 9 2017 ») — les blocs du pilote sont entièrement chiffrés, signe d'un format de signature plus récent.

## État honnête
Candidats réduits à **~5 blocs chiffrés** ; les blocs ressemblant à du code sont éliminés. Reste à **relier un bloc précis au chargeur PMU** (la fonction qui écrit dans `IMEMD`/`DMEMD0` à 0x10a1c4/0x10a1e4) via les références croisées — c'est l'étape rizin. Micrologiciel **pas encore identifié ni extrait**.
