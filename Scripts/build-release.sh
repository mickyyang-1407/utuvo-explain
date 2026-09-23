#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
xcodegen generate
xcodebuild -quiet -project UTUVOExplain.xcodeproj -scheme UTUVOExplain \
  -configuration Release -derivedDataPath build build

app_path="build/Build/Products/Release/UTUVO Explain.app"
codesign --force --deep --options runtime \
  --sign 'Developer ID Application: MIN CHI YANG (RPNT54P79S)' "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built and signed: $app_path"
