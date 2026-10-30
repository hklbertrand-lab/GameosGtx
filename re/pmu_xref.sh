#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/pmu_xref.rz" ./pmu_xref.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
nohup bash -c "rizin -q '$B' < pmu_xref.rz > pmu_xref.out 2> pmu_xref.err" &
echo "rizin pmu_xref pid $! -> pmu_xref.out (~3-5 min)"
