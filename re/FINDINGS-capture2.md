# Capture 2 (20261029-200719) — montée en fréquence sous charge GPU

Trace de 21,2 M lignes, propre (aucun événement perdu). Charge OpenCL [gpu_load.c](gpu_load.c), 15 s. Le script `capture.sh` corrigé fonctionne de bout en bout.

## La carte a bien changé de régime (clocks-timeline.txt)
| Moment | Fréquence GPU | Mémoire | Puissance | P-state |
|---|---|---|---|---|
| Avant charge | 1430 MHz | 5508 | 63 W | P0 (repos) |
| Montée | 1164 → 1518 → 1670 → 1911 MHz | 5005 | 56 → 243 W | P2 (charge compute) |
| Pleine charge | ~1898 MHz | 5005 | ~238 W | P2 |
| Après charge | 1898 MHz | 5508 | ~88 W | P0 |

C'est exactement ce qui manquait à la capture 1 : une vraie transition pilotée par le PMU, du repos à la pleine puissance (243 W).

## Activité PMU par scénario
| Scénario | Accès PMU |
|---|---|
| S10 repos | 4 551 |
| **S11 sous charge** | **17 367** (le plus actif) |
| S12 fin de charge | 918 |

Le PMU est ~4× plus sollicité sous charge qu'au repos : c'est lui qui conduit la montée en fréquence.

## Le canal de commande fréquence/tension est identifié
Pendant S11, les écritures PMU passent par :
- **`DMEMC0`/`DMEMD0`** (0x1e0/0x1e4) : fenêtre d'accès à la mémoire de données du PMU — c'est là que le pilote dépose les commandes de changement de régime.
- **`MAILBOX0`/`MAILBOX1`** (0x180/0x184) : échange de paramètres pilote ↔ PMU.
- **files de messages `0x4c8`/`0x4cc`** : têtes/queues des files commande et message (déjà vues en capture 1).

C'est le protocole concret à décoder aux étapes 4 et 5 : le pilote écrit une commande « passe à tel niveau de performance » dans la DMEM via `DMEMD0`, pousse la file `0x4cc`, et le PMU exécute le changement de fréquence et de tension.

## Pour la suite
- On a maintenant, côté matériel, **la séquence de référence** d'un reclock réussi : à reproduire depuis nouveau une fois le micrologiciel PMU chargé (étape 5).
- Le décodage précis des octets de commande (format de la structure déposée en DMEM) se fera avec le contexte du désassemblage Ghidra (étape 2b/4), en recoupant les écritures `DMEMD0` de S11 avec les symboles `RmPmu…`.
