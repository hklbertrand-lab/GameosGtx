#!/usr/bin/env bash
cd "$HOME/gameos-re3"
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
echo "=== rizin version ==="; rizin -v | head -1
echo "=== run ==="
rizin -q "$B" < "$HOME/gameos/re/pmu_fn.rz" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | sed -n '1,120p'
echo "=== fin (exit ${PIPESTATUS[0]}) ==="
