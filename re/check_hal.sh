#!/usr/bin/env bash
set -euo pipefail
REL=/tmp/gameos-rela.txt
for fn in _nv048615rm _nv048617rm _nv048649rm; do
  pc=$(grep -cE "R_X86_64_PC32 *$fn([-+ ]|\$)" "$REL" || true)
  d64=$(grep -cE "R_X86_64_64 *$fn([-+ ]|\$)" "$REL" || true)
  printf "%s : appels_directs=%s  dans_table_64bit=%s\n" "$fn" "$pc" "$d64"
done
echo "=== emplacements .data de _nv048617rm (table HAL) ==="
grep -E "R_X86_64_64 *_nv048617rm([-+ ]|\$)" "$REL" | head
