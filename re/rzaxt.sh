#!/usr/bin/env bash
# aaa + xrefs getters + datarefs base PMU. Ni -c multiligne ni -i ne marchent
# sur ce rizin : on alimente les commandes par STDIN (lues ligne par ligne).
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/axt.rz" ./axt.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
nohup bash -c "rizin -q '$B' < axt.rz > axt.out 2> rzaxt.err" &
echo "rizin axt pid $! -> axt.out (~3-5 min)"
