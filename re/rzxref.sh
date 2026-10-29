#!/usr/bin/env bash
cd "$HOME/gameos-re3"
ls -la aaa.rzdb 2>/dev/null || echo "PAS DE PROJET"

rizin -q -c '
  Po aaa.rzdb
  echo "=== flags getters ===";
  f~048615;
  f~048617;
  f~048649;
  echo "=== xrefs 615 ==="; axt @ sym._nv048615rm;
  echo "=== xrefs 617 ==="; axt @ sym._nv048617rm;
  echo "=== xrefs 649 ==="; axt @ sym._nv048649rm;
  echo "=== nb fonctions analysees ==="; aflc;
' /usr/src/nvidia-580.196.07/nvidia/nv-kernel.o_binary 2>/dev/null
