#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

images=(docs/assets/*.webp(N))
(( ${#images} == 9 )) || { print -u2 'Expected nine optimized WebP images.'; exit 1; }
total=0
for image in "${images[@]}"; do
  size=$(stat -f %z "$image")
  (( size <= 180000 )) || { print -u2 "Image exceeds 180 KB: $image ($size bytes)"; exit 1; }
  total=$((total + size))
  print "$image: $size bytes"
done
(( total <= 600000 )) || { print -u2 "Web image budget exceeded: $total bytes"; exit 1; }
if rg -n 'docs/assets/[^" ]+\.png|assets/[^" ]+\.png' README.md README.en.md docs/*.html; then
  print -u2 'README or site references a PNG image instead of optimized WebP.'
  exit 1
fi
print "Web image budget passed: $total bytes total"
