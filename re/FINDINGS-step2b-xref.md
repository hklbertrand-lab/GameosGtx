# Étape 2b (références croisées) — jusqu'où on est allé

## Ce qui est établi
Chaque bloc chiffré candidat est référencé **une seule fois**, depuis `.text`, dans une fonction « fournisseuse » de micrologiciel :

| Fonction | Charge le jeu | Sélecteur juste avant |
|---|---|---|
| `_nv048615rm` | `_nv046230rm` + `_nv046224rm` (48 Ko) | `mov $0x7,%esi` |
| `_nv048617rm` | `_nv046232rm` + `_nv046226rm` (95 Ko) | `mov $0x7,%esi` |
| `_nv048649rm` | `_nv056767/8/5/6rm` (72 Ko) | `mov $0x2,%esi` |

Ce sont des « GetBinArchive » : chacune renvoie un jeu {image + signature (+ descripteur)} pour un moteur Falcon donné. Le `mov $imm,%esi` répété est un sélecteur (puce/variante).

## Le mur : indirection par HAL
Pour savoir **laquelle** charge le PMU, il faut remonter à l'appelant qui manipule la base Falcon du PMU (`0x10a000`). Or :
- **0 appel direct** (R_X86_64_PC32) vers ces fonctions,
- **0 adresse en table** (R_X86_64_64).

Explication : les appels **internes à `.text`** sont encodés en relatif et **ne génèrent aucune relocation** dans un `.o` unique. Les relocations ne couvrent que les données (les blocs firmware) et les symboles externes. Donc le graphe d'appels n'est pas lisible via les relocations : il faut **désassembler tout `.text` et suivre les cibles des `call`** — c'est de l'analyse complète (rizin `aaa` ou équivalent), lourde sur 14 Mo de code et 62 000 symboles anonymisés.

## Point de lucidité
- On a réduit la cible à **3 jeux de micrologiciel** et identifié leurs fonctions fournisseuses — vrai progrès, reproductible.
- L'identification fine du PMU, puis l'extraction, demandent l'analyse complète du binaire (prochaine session dédiée).
- Rappel : même extrait, le micrologiciel est **chiffré et signé**. C'est exactement là que l'effort historique de nouveau sur le reclocking Pascal s'est arrêté. On a confirmé concrètement le format chiffré (plus l'ancien `desc`+clair). Les chances d'aboutir à un reclocking complet restent faibles ; ce qu'on produit a surtout de la valeur comme cartographie documentée.

## Prochaine étape proposée
Analyse complète avec rizin (`aaa`) lancée en tâche de fond sur la machine, puis résolution du graphe d'appels des 3 fournisseuses jusqu'à la base PMU `0x10a000`. À faire dans une session dédiée, après avoir commité l'existant.
