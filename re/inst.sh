#!/usr/bin/env bash
cd "$HOME/gameos-re3"
for g in _nv048615rm _nv048617rm _nv048649rm; do
  echo "===== $g ====="
  echo "-- instruction(s) référençant <$g> exactement --"
  grep -E "<$g>([^0-9a-f]|$)" text.dis | grep -vE '^[0-9a-f]+ <' | head
done
echo "===== rizin aaa statut ====="
pgrep -a rizin || echo "absent"
ls -la aaa.done 2>/dev/null && echo "aaa fini" || echo "aaa pas fini"
