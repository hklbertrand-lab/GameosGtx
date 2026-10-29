#!/usr/bin/env bash
set +e
echo "=== gcc ==="; command -v gcc && gcc --version | head -1 || echo "gcc absent"
echo "=== make ==="; command -v make && make --version | head -1 || echo "make absent"
echo "=== kernel build tree (headers) ==="
K="/lib/modules/$(uname -r)/build"
echo "$K"
if [ -d "$K" ]; then
    ls -ld "$K"
    [ -f "$K/Makefile" ] && echo "Makefile present" || echo "Makefile ABSENT"
    [ -f "$K/include/linux/kprobes.h" ] && echo "kprobes.h present" || echo "kprobes.h ABSENT"
else
    echo "ARBRE BUILD ABSENT"
fi
echo "=== bpftrace (alternative plus lourde) ==="; command -v bpftrace || echo "absent"
echo "=== kallsyms lisible en root ? (adresses non nulles) ==="
grep -m1 -E '_nv048615rm' /proc/kallsyms 2>/dev/null || echo "(non lisible en non-root — normal)"
