#!/usr/bin/env bash
cd "$HOME/gameos-re3"
sed 's/\x1b\[[0-9;]*m//g' pmu_xref.out
echo "===== ERR (tail) ====="
tail -3 pmu_xref.err 2>/dev/null
