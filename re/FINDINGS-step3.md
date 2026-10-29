# Étape 3 — graphe d'appels complet de `nv-kernel.o_binary`

## Ce qui a été fait (reproductible, scripts dans `re/`)
- `callgraph.sh start` : désassemblage **objdump complet** de `.text` (117 Mo, `text.dis`) + `rizin aaa` lancés en tâche de fond sur la machine. L'objdump termine en ~1 min ; `aaa` s'est terminé (`aaa.done`).
- `callgraph.sh graph` : extraction de **31 565 arêtes d'appel direct** depuis le désassemblage, plus la liste des fonctions touchant la base Falcon du PMU `0x10a000`.
- `callers.sh` / `inst.sh` : remontée ciblée des appelants des 3 fournisseuses de micrologiciel.
- `rzaxt.sh` : relance `aaa` + `axt` (xrefs) + recherche de pointeurs données vers `0x10a000`, résultat écrit dans `gameos-re3/axt.out` **(tâche de fond, à relire à la prochaine session).**

Tout tourne dans `~/gameos-re3` sur la box (hors dépôt).

## Résultat décisif : les fournisseuses n'ont AUCUNE référence statique
En cherchant le symbole exact `<_nv048615rm>` / `<_nv048617rm>` / `<_nv048649rm>` dans **tout** `text.dis` :
- **0** instruction `call` vers leur point d'entrée (offset 0),
- **0** instruction `lea`/`mov` prenant leur adresse,
- la seule occurrence était leur propre **ligne de définition**.

Les 197 « call ... `<_nv048615rm+0xNNN>` » repérés au premier passage sont en fait des appels vers de **petites fonctions anonymes situées après** le getter ; objdump les rattache au symbole nommé précédent. Ce ne sont pas des appels du getter.

### Conséquence
Confirmation rigoureuse (désassemblage, plus seulement relocations) du mur de l'étape 2b :
les getters de micrologiciel sont atteints **uniquement par répartition HAL à l'exécution** — leur adresse est placée dans une table de pointeurs de fonctions **remplie au démarrage**, sans relocation ni prise d'adresse statique visible dans ce `.o` unique. Le graphe d'appel statique ne peut donc pas relier « base PMU `0x10a000` » → « getter du PMU ».

## Cartographie du cluster PMU (`0x10a000`)
233 fonctions référencent la plage `0x10axxx`. Les plus denses (candidates aux accès registres/commande du PMU) :

| Fonction | #réf 0x10a | Rôle probable |
|---|---|---|
| `_nv051232rm` | 23 | accès registres PMU |
| `_nv051238rm` | 22 | accès registres PMU |
| `_nv042829rm` / `_nv042826rm` / `_nv042825rm` | 18 ch. | init/bootstrap Falcon PMU |
| `_nv052378rm` / `_nv052285rm` / `_nv042828rm` | 8 ch. | — |

## Où ça coince (inchangé, mais maintenant prouvé par le désassemblage)
La liaison « quel getter charge le PMU » passe par des pointeurs installés à l'exécution,
invisibles en statique dans le `.o`. Et le micrologiciel reste **chiffré et signé** : c'est
exactement là que l'effort historique de nouveau sur le reclocking Pascal s'est arrêté.

## PERCÉE : les constructeurs de la table HAL (axt.out)
`rizin aaa` (59 512 fonctions) + `axt` ont résolu les **xrefs de données** que objdump et les
relocations ne voyaient pas. Chaque getter est installé dans une table de pointeurs par une
fonction d'init (`rdi` = objet HAL/moteur, rizin nomme le champ d'après le getter) :

| Initialiseur | Site | Instruction |
|---|---|---|
| `_nv048965rm` | `0x8df47e6` | `mov qword [rdi + sym._nv048615rm], 0x8e17180` |
| `_nv048966rm` | `0x8e3599b` | `mov qword [rdi + sym._nv048617rm], 0x8e652b0` |
| `_nv048965rm` | `0x8df455d` | `mov qword [rdi + sym._nv048649rm], 0x8e19940` |

→ **`_nv048965rm` et `_nv048966rm` sont les constructeurs de la table HAL** : c'est le chaînon
que le graphe d'appel statique ne pouvait pas fournir. Les immédiats (`0x8e17180`,
`0x8e652b0`, `0x8e19940`) sont les vraies adresses de handlers rangées à côté des getters.

Méthode qui marche enfin : `rizin -q "$B" < axt.rz` (commandes par **stdin**) — `-c` multiligne
et `-i` échouent tous deux sur ce rizin. `?e` (echo) non supporté → pas de marqueurs, sans gravité.

## Prochaines pistes (nouvelle session)
1. **Désassembler `_nv048965rm` / `_nv048966rm` en entier** : lire toute la table de pointeurs
   construite, repérer l'entrée associée à la base PMU `0x10a000` → on relie enfin le PMU à son
   getter de micrologiciel. (`pdf @ sym._nv048965rm` dans rizin.)
2. Croiser avec le cluster PMU (233 fonctions, `_nv051232/051238/042829rm`…) pour confirmer
   quelle entrée HAL pilote le PMU.
3. Rappel : même relié et extrait, le micrologiciel reste **chiffré et signé** — la valeur
   reste la cartographie, pas un reclocking complet probable.
