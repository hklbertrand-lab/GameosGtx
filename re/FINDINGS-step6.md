# Étape 6 — CORRECTION : les getters suivis depuis l'étape 2b sont du NVSwitch, pas le PMU GeForce

## Le constat
Désassemblage des 3 getters (`_nv048615rm` @0x8e17180, `_nv048617rm` @0x8e652b0,
`_nv048649rm` @0x8e19940) + lecture des chaînes qu'ils atteignent :

- **Getter 649** imprime via `nvswitch_os_print` / `nvswitch_os_report_error` la chaîne
  `"nvidia-%s: SXid ... SOE reset timeout error"`. **SOE = Security Offload Engine du NVSwitch.**
- **Getters 615/617** : mêmes champs d'objet (`r15+0x948/0x950`, `r15+0x2100/0x20f8`), sélecteur
  `esi=7`, et tout le voisinage de chaînes est **MINION / NVLink / NVSwitch**.
- Le constructeur de la table HAL (étape 4, `_nv048965rm`) est appelé depuis
  `nvswitch_lib_register_device`.

## Conclusion
**Depuis l'étape 2b, on a cartographié le chemin firmware du NVSwitch/NVLink (SOE, MINION),
pas celui du PMU de la GeForce.** Le scan par entropie de l'étape 2b avait sélectionné les plus
gros blobs chiffrés — justement les micrologiciels datacenter (GSP/MINION/SOE) du pilote unifié.
Ce code **ne s'exécute jamais sur une GTX 1080 Ti**, ce qui explique proprement les **0 hit
de l'étape 5** : ce n'était pas « one-shot caché » mais du **code mort sur ce GPU**.

Les étapes 3 et 4 (graphe d'appels, table HAL, méthode kprobe) restent valides en tant que
**méthode** ; seule la **cible** était la mauvaise.

## Le vrai PMU GeForce : chaînes repères (présentes dans le binaire)
- `"An uncorrectable ECC error has been detected on GPU in the PMU Falcon"` @ 0x5d6ba10
- `"Falcon ucode"` @ 0x5c65dc8, `"FECS ucode"` @ 0x5d023cf, `"FB Falcon"` @ 0x5c87043
- `RMExecuteDevinitOnPmu`, `RMPcieGenSwitchOnPmu`

Pascal (gp102) n'utilise pas GSP-RM (offload Turing+), donc le bootstrap du PMU est côté CPU
dans `nv-kernel.o_binary` : il est trouvable.

## Le vrai cluster PMU GeForce (trouvé)
Recherche de l'immédiat **exact** `$0x10a000` (base falcon PMU/PWR GeForce) dans `text.dis`
(objdump) — 12 sites, fonctions englobantes :

| Fonction | #réf | Nature |
|---|---|---|
| `_nv052191rm`, `_nv052193rm`, `_nv052194rm` | 2 ch. | **minces accesseurs** : `mov $0x10a000,%esi ; call <helper>` ×2 (lecture/écriture registre PMU) |
| `_nv052516rm`, `_nv052223rm`, `_nv052168rm`, `_nv052166rm` | 1 | accès PMU |
| `_nv030959rm`, `_nv030960rm` | 1 | accès PMU |

Ce sont les fonctions GeForce du cluster `_nv052xxx` (cohérent avec l'étape 3). Le **bootstrap**
du falcon PMU (DMA du micrologiciel : DMATRFBASE→BOOTVEC=0x50→CPUCTL=0x5e00, cf. étape 2a) n'est
PAS dans ces accesseurs : il tient vraisemblablement la base PMU dans un registre (pas en
immédiat), donc invisible à cette recherche. Candidats restants : `_nv052516rm`, `_nv030959/960rm`.

## Outillage / limites constatées
- rizin 0.8.2 analyse mal ce `.o` REL (maps `.rela` illisibles → `aaa` ne borne pas les
  fonctions ; `af`/`axt`/`?e` peu fiables). **`objdump` sur `text.dis` reste l'outil de référence.**
- Attention aux espaces d'adresses : vaddr rizin (`0x8xxxxxx`) ≠ offset de section objdump.
- `$0x10a000` ≠ `$0x10a0000` : filtrer précisément.

## Prochaine étape
Trouver le **bootstrap PMU GeForce** = la fonction qui écrit DMATRFBASE/BOOTVEC/CPUCTL au falcon
PMU et référence (reloc .data) le **blob ucode PMU**. Partir de `_nv052516rm`/`_nv030959rm`, ou
suivre les accesseurs minces jusqu'à leur appelant qui met la base en registre. Le blob reste
**chiffré et signé** : objectif = cartographie, pas reclocking.

## Rappel de lucidité
Le micrologiciel PMU GeForce reste **chiffré et signé** : même bien ciblé, l'objectif reste la
cartographie, pas un reclocking complet probable.
