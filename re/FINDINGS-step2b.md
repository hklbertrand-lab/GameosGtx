# Étape 2b — cartographie de nv-kernel.o_binary (pilote 580.196.07, 107 Mo)

Scanner [scan_driver.py](scan_driver.py) : entropie par fenêtre + table des symboles. Sorties dans `driver-scan/` (hors git).

## Entropie
- **221 régions** à haute entropie (≥ 7,5), soit **75 Mo sur 107** : le binaire est surtout fait de micrologiciels embarqués.
- La plupart sont des **images GSP des cartes récentes** (Turing et plus, cœur RISC-V) : la plus grosse fait 21 Mo (0x01d31000). Elles ne nous concernent pas.
- Le micrologiciel PMU d'une Pascal est au contraire **petit** (quelques dizaines de Ko) : il ne ressort pas par la taille. Il faut passer par les symboles.

## Symboles du chargeur PMU (trouvés)
Vers l'offset 0x5d6b000, les chaînes du code de chargement du PMU :
```
RmPmuUcodeProfile   PMU ucode   RmPmuBootstrapMode   RmPmuUcodeAddrMode
RmPmuForcePhysMappings   RmPmu20DriverRegisterSync
```
Chaînes Pascal présentes (`pascal/…​.c`, `Quadro GP100`, `TITAN X (Pascal)`, `kbusInitInstBlk_GP100`) : le code Pascal est bien dans ce binaire.

## Conclusion de 2b (1er passage)
- Le micrologiciel PMU **est embarqué** et chargé par ces fonctions `RmPmu…`. Cohérent avec la trace (DMA → BOOTVEC → CPUCTL, sans SEC2).
- L'entropie seule ne suffit pas à l'isoler (noyé parmi les GSP). **La suite est du désassemblage** : ouvrir `nv-kernel.o_binary` dans Ghidra, suivre la fonction qui référence `RmPmuUcodeProfile` / « PMU ucode » jusqu'au symbole de données du micrologiciel, lire sa taille et son descripteur, puis extraire ces octets.
- C'est le gros morceau du projet (plusieurs sessions). Validation : comparer la taille et l'en-tête extraits avec ceux attendus par le format `sec2/desc+image+sig` public de la GP102.

## État honnête
On sait **où chercher** (symboles `RmPmu…`, binaire du pilote) et **comment valider**. On n'a **pas encore extrait** l'image PMU : ça demande l'étape de désassemblage ci-dessus, qui n'est pas automatisable en un scan.
