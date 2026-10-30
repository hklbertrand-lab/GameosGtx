# Étape 7 — chasse au bootstrap PMU GeForce : carte du chemin registre + mur HAL

## Ce qui est établi (chemin registre PMU GeForce)
En désassemblant (objdump -dr) les fonctions qui portent l'immédiat `$0x10a000` :

| Fonction | Rôle |
|---|---|
| `_nv030978rm` | **primitive générique d'écriture registre GPU** (appelée partout, PC32 ; avec base `0x10a000` pour le PMU) |
| `_nv030959rm` | test de plage : `sub $0x10a000 ; cmp $0xfff`  → « adresse dans le bloc PMU ? » (fenêtre 0x10a000–0x10afff) |
| `_nv030960rm` | idem, fenêtre 0x10a000–0x10bfff |
| `_nv052191rm`, `_nv052193rm`, `_nv052194rm` | accesseurs minces : `mov $0x10a000,%esi ; call _nv030978rm` (lecture/écriture registre PMU) |
| `_nv052166rm`, `_nv052168rm`, `_nv052516rm` | helpers de commande/log PMU : séquences `mov $0xVV0000,%esi ; mov $strptr,%edi ; call _nv047875rm` + `call _nv046751rm`, IDs 0x5a/0x5d/0x25e/0x261/0x312/0x315 |
| `_nv052162rm` → `_nv052168rm`, `_nv052225rm` → `_nv052223rm` | seuls appelants PC32 trouvés (dispatch de commande) |

## Le mur : indirection HAL non résolue par l'outillage
- `text.dis` est un `objdump -d` **sans relocations** : dans un `.o`, les `call` inter-fonctions
  ont un rel32 = 0 (non résolu), donc les cibles y sont **fausses**. **Le vrai graphe d'appels
  d'un `.o` = les relocations** (`objdump -r`). Correction méthodologique importante.
- Via les relocs : les accesseurs purs `_nv052191/193/194rm` n'ont **ni appelant `R_X86_64_PC32`
  ni pointeur `R_X86_64_64`**. Ils sont donc câblés par le **schéma HAL généré** du RM (table
  relative) que ni `objdump` ni `rizin 0.8.2` ne reconstruisent sur ce `.o` à 62 000 symboles
  anonymisés.
- Le **bootstrap PMU** (DMA de l'ucode : DMATRFBASE/BOOTVEC/CPUCTL) tient la base PMU **dans un
  registre** (depuis le descripteur de moteur), donc il ne porte pas l'immédiat `0x10a000` et
  n'est pas atteignable par cette recherche. Son blob ucode (reloc `.data`) reste donc non
  localisé.

## Conclusion honnête
On a cartographié proprement le **chemin registre du PMU GeForce** (primitive, fenêtres,
accesseurs, helpers de commande). Mais le **bootstrap + le blob ucode** sont derrière
l'indirection HAL générée, que l'outillage disponible (objdump, rizin 0.8.2) ne perce pas sur ce
`.o`. Et même atteint, le micrologiciel reste **chiffré et signé**.

→ Plafond pratique de l'analyse statique **avec cet outillage**. Pour aller plus loin il
faudrait un désassembleur qui applique les relocations du `.o` et reconstruit les tables HAL
générées (type Ghidra avec script HAL) — non viable sur ces machines (noté étape 2b). La valeur
produite reste la **cartographie documentée**, pas un reclocking.

## Piste résiduelle (long shot)
Le getter d'ucode PMU GeForce existe sans doute (analogue aux getters NVSwitch, mais sélecteur
moteur différent). Le trouver demanderait de reconstruire la table HAL PMU (constructeur façon
étape 4) — même mur d'indirection. À tenter seulement avec un meilleur désassembleur.
