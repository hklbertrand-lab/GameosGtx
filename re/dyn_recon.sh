#!/usr/bin/env bash
# Recon faisabilite analyse dynamique (sans sudo, sans rien perturber).
set +e
echo "=== noyau ==="
uname -r
echo "=== module nvidia charge ? ==="
lsmod | grep -E '^nvidia' || echo "(nvidia non charge)"
echo "=== support kprobe/ftrace dans la config ==="
if [ -r /proc/config.gz ]; then
    zcat /proc/config.gz | grep -E 'CONFIG_(KPROBES|KPROBE_EVENTS|FUNCTION_TRACER|DYNAMIC_FTRACE|STACKTRACE)='
else
    K=/boot/config-$(uname -r)
    [ -r "$K" ] && grep -E 'CONFIG_(KPROBES|KPROBE_EVENTS|FUNCTION_TRACER|DYNAMIC_FTRACE|STACKTRACE)=' "$K" || echo "(config noyau illisible en non-root)"
fi
echo "=== les getters sont-ils dans kallsyms du module ? (nom seul, adresse masquee en non-root) ==="
grep -E '_nv048(615|617|649)rm' /proc/kallsyms 2>/dev/null | head || echo "(absent ou kallsyms masque)"
echo "=== combien de symboles _nvXXXXrm exposes par le module ==="
grep -c ' \[nvidia\]$' /proc/kallsyms 2>/dev/null || echo "(kallsyms non lisible)"
echo "=== outils dispo ==="
for t in gdb perf trace-cmd drgn crash bpftrace; do
    command -v "$t" >/dev/null 2>&1 && echo "  OK  $t ($( $t --version 2>/dev/null | head -1 ))" || echo "  --  $t absent"
done
echo "=== /sys/kernel/debug monte ? (lecture seule, peut etre root-only) ==="
mount | grep -E 'debugfs|tracefs' || echo "(pas visible)"
