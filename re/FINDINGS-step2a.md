# Étape 2a — résultats de l'analyse de la trace (capture 20261029-192608)

Trace de 30 182 623 lignes, analysée avec [analyze_pmu.py](analyze_pmu.py). Sorties brutes dans `analysis/` (hors git).

## Accès aux processeurs internes, par scénario
| Scénario | PMU | SEC2 | FB (mémoire) |
|---|---|---|---|
| S1 `modprobe nvidia` | 7 405 | 0 | 12 793 |
| S3 init GPU | 69 | 0 | 0 |
| S5/S6 (fréquence, refusée) | 92 / 92 | 0 | 0 |
| S8/S9 limite de puissance | 183 / 201 | 0 | 0 |
| S10 repos | 1 850 | 0 | 6 |
| END (blocage) | 14 420 | 0 | 3 840 |

## Ce qu'on apprend
1. **Le micrologiciel PMU est chargé par DMA, pas écrit en clair.** En S1 : écritures `DMATRFBASE`/`DMACTL`/`DMATRFCMD`, puis `BOOTVEC=0x50` et `CPUCTL=0x5e00` (lancement du processeur). Seuls 52 octets passent par `IMEMD` (sans doute le tout petit amorçage). Le corps du micrologiciel n'apparaît donc pas dans la trace — il faut l'extraire du binaire du pilote (étape 2b).

2. **SEC2 n'est jamais touché (0 accès).** Le pilote propriétaire 580 démarre le PMU directement avec son propre amorçage signé (DMA → BOOTVEC → CPUCTL), sans passer par le chemin ACR/SEC2 qu'utilise nouveau. C'est plutôt favorable : l'amorçage signé dont on a besoin est fourni par le pilote lui-même.

3. **Les files de messages du PMU sont identifiées.** Registres `0x4c8`/`0x4cc` (~4 240 accès chacun) = têtes/queues des files commande/message. C'est le canal par lequel le pilote pilote les fréquences et les tensions : la base du travail des étapes 4 et 5.

## Où sont les micrologiciels (préparation 2b)
- **Public** (`/usr/lib/firmware/nvidia/gp102/`, via linux-firmware) : `acr/`, `sec2/`, `gr/`, `nvdec/scrubber`. **Pas de PMU.**
- **Propriétaire** : `/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary` (108 Mo) contient le micrologiciel PMU signé de la GP102. C'est la cible de l'extraction.

## Étape 2b — plan
1. Repérer les blocs Falcon dans `nv-kernel.o_binary` (en-têtes `NVIDIA`/`FWHD`, descripteurs de taille, zones signées).
2. Isoler le PMU GP102 par recoupement avec la trace : taille et premiers octets de l'amorçage vus via `IMEMD`/`DMATRF` en S1.
3. Comparer la mise en forme avec les blobs publics `sec2/` (mêmes en-têtes `desc`/`image`/`sig`) pour savoir comment présenter le PMU extrait à nouveau (préparation étape 4).

## Limite de la capture 1
Le blocage de fréquence est refusé sur GeForce Pascal : S5/S6 ne contiennent aucun changement réel. La capture 2 devra forcer la montée en fréquence avec une vraie charge GPU (petit programme Vulkan), script `capture.sh` corrigé à réinstaller au préalable.
