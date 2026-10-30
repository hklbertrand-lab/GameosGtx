#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/gameos-re3"
cp -f "$HOME/gameos/re/pmu_fn.rz" ./pmu_fn.rz
B=/usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary
# enclosing functions des sites du cluster 0x8ec*
printf 'aaa\ne scr.color=0\n' > /tmp/encl.rz
for a in 08ec2468 08ec28b8 08ec2d98 08ec3278 08ec38f8 08ec3ee8 08ec4708 08ec4f48 08ec5418 08ec5ce8 08ec6168 08ec65c8 08ec6d98 08ec7518 08ec79f0 08ec8590 08ec8aa0 08ec8fa0 08ec9b48 08eca708 08ecac38 08ecb778 08ecbd38 08ecc840 08eccf58 08ece1f8 08ece8a8 08ecfbe8; do
  printf 's 0x%s; af; afo\n' "$a" >> /tmp/encl.rz
done
echo "===== fonctions englobantes du cluster 0x8ec (base PMU 0x10a000) ====="
rizin -q "$B" < /tmp/encl.rz 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^0x' | sort | uniq -c | sort -rn
