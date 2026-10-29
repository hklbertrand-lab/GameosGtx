# Étape 5 — analyse dynamique (kprobe) : résultat négatif documenté

## Objectif
Capturer la pile d'appel des 3 getters de micrologiciel à l'exécution pour relier
chaque getter à son moteur (PMU compris), là où le statique bloque (table HAL générique).

## Ce qui marche
- **`register_kprobe()` (module noyau) peut sonder les fonctions du module NVIDIA**, contrairement
  à l'interface tracefs `kprobe_events` qui les refuse (`within_notrace_func` → « Could not probe
  notrace function » : le module propriétaire est compilé sans site fentry).
- Module `kp/kp_getters.c` (+ Makefile) : compile proprement, arme les 3 kprobes, `dump_stack()`
  dans le pre_handler. Lanceur `kp_run.sh` (sudo) : décharge/recharge le pilote, arme, récupère
  dmesg. Outils réutilisables.

## Le mur (confirmé par 3 captures)
**Les getters ne sont appelés qu'une seule fois, au tout premier `module_init` de nvidia, puis
le résultat est mis en cache.** Impossible d'armer un kprobe avant cette première init :
1. il faut le module chargé pour résoudre le symbole (par nom) ou connaître l'adresse ;
2. mais à ce stade l'init a déjà eu lieu → firmware déjà chargé et caché.

Pistes essayées, toutes 0 hit :
- armement par adresse, puis `nvidia-smi` / `--gpu-reset` → le reset est refusé (GPU primaire) ;
- armement par adresse (module kp gardé chargé), puis **détach/réattach PCI** du GPU
  (`unbind`/`bind`) → le réattachement ne rappelle pas les getters (firmware caché, pas rechargé) ;
- auto-bind PCI coupé pour charger nvidia sans init → nvidia refuse (`No such device`) ;
- armement **par nom de symbole** puis décharge/recharge nvidia, en pariant sur le ré-armement
  à `MODULE_STATE_COMING` → **faux** : au déchargement le noyau marque le kprobe **GONE**
  (définitivement mort), il n'est pas ré-armé. dmesg du rechargement : init complète, aucun
  `armed`/`hit`.

→ **L'approche « tracer le getter par kprobe » est une impasse** pour un appel one-shot caché.

## Ce qu'on en retient
- Le lien getter↔PMU ne se fera pas en traçant le getter.
- Avenues restantes :
  1. **Statique (gratuit, sans perturbation)** : désassembler les 3 getters et lire l'identifiant
     de moteur/falcon qu'ils embarquent (ou le descripteur renvoyé) → dire quel getter est le PMU.
     Rappel correspondance étape 2b : getter `_nv048615rm`→blob 48K, `_nv048617rm`→95K,
     `_nv048649rm`→72K.
  2. **Dynamique sur le chemin RUNTIME du PMU** (pas l'init, donc pas de problème de timing) :
     kprobe sur un accesseur PMU du cluster des 233 fonctions (`_nv051232rm`…), armé en continu,
     puis charge GPU (reclock) → pile d'appel du chemin de commande PMU vivant. Cartographie le
     PMU en marche, sans toutefois identifier le getter de firmware.
- Dans tous les cas, le micrologiciel reste **chiffré et signé** : plafond déjà connu.
