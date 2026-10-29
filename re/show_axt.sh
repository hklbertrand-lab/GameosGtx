#!/usr/bin/env bash
cd "$HOME/gameos-re3"
echo "taille axt.out: $(wc -c < axt.out) octets"
echo "--- contenu axt.out ---"
cat axt.out
echo "--- rzaxt.err ---"
cat rzaxt.err
