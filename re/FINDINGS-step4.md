# Étape 4 — la table HAL désassemblée

## Ce qui a été fait
`hal.sh` (rizin par stdin, `hal.rz`) désassemble les deux « initialiseurs » repérés à
l'étape 3 et extrait toutes les affectations de pointeurs. Sorties rapatriées dans le dépôt :
- `hal.dis` (92 Ko) — désassemblage des deux fonctions,
- `hal_table.txt` — les ~400 entrées extraites (champ → fonction).

## Résultat : un unique constructeur de vtable HAL géant
Les deux adresses de l'étape 3 (`_nv048965rm`, `_nv048966rm`) font partie d'**un seul grand
constructeur de table HAL** (`_nv048965rm`, appelé depuis l'enregistrement du device —
`nvswitch_lib_register_device` selon rizin, c.-à-d. l'init device du RM unifié). Il range
**~400 pointeurs de fonctions** dans une struct passée en `rdi`. C'est la table de répartition
de tous les moteurs du RM.

Nos trois getters de micrologiciel y figurent comme entrées (relocations à l'appui) :

```
0x08df47e6  mov qword [rdi + _nv048615rm], 0x8e17180   ; RELOC _nv048615rm @ 0x8e17180
0x08e3599b  mov qword [rdi + _nv048617rm], 0x8e652b0   ; RELOC _nv048617rm @ 0x8e652b0
0x08df455d  mov qword [rdi + _nv048649rm], 0x8e19940   ; RELOC _nv048649rm @ 0x8e19940
```

Les octets à chaque cible (`f3 0f 1e fa 55 48 89 e5` = `endbr64; push rbp; mov rbp,rsp`)
confirment que ce sont bien des **fonctions** : le symbole `_nv0486XXrm` désigne la fonction,
son adresse est l'immédiat rangé dans le champ de la struct.

## Le mur, précisé
- **Aucune référence à la base PMU `0x10a000`** dans tout le constructeur : normal, la table
  ne fait que câbler des pointeurs ; l'accès registres PMU vit dans les *handlers* appelés via
  la table, pas dans le câblage.
- Les trois getters ont le **même prologue générique** : rien ne distingue le PMU à ce niveau.
- La table est **générique** (tous moteurs confondus) ; identifier l'entrée PMU demande de
  relier un champ de la struct à l'usage côté PMU, ce que le statique ne donne pas facilement
  (le champ n'est qu'un décalage dans `rdi`).

## Lucidité
On a désormais la **cartographie complète du câblage HAL** et la confirmation que les trois
getters de micrologiciel y sont branchés. Mais :
1. la table étant générique, l'association champ ↔ moteur PMU n'est pas lisible en statique ;
2. le micrologiciel reste **chiffré et signé**.

On approche du plafond réaliste de l'analyse **statique**. La vraie valeur produite est la
carte documentée (registres PMU, canal de commande DMEM, cluster de 233 fonctions, table HAL).

## Prochaine étape (analyse dynamique)
`gdb` sur le pilote 580 chargé :
1. point d'arrêt à l'entrée d'un getter (`0x8e17180` / `0x8e652b0` / `0x8e19940`) et lecture de
   la pile d'appel → quel moteur l'invoque ;
2. ou point d'arrêt sur l'accès à la base PMU `0x10a000` et remontée jusqu'au champ de la
   vtable utilisé → relie enfin le PMU à son getter.
Cela contourne l'absence de lien statique, mais ne lève pas le chiffrement du blob.
