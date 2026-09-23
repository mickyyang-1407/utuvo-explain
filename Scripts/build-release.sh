#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
xcodegen generate
xcodebuild -quiet -project UTUVOExplain.xcodeproj -scheme UTUVOExplain \
  -configuration Release -derivedDataPath build build

app_path="build/Build/Products/Release/UTUVO Explain.app"
codesign --force --deep --options runtime \
  --sign "$SIGNING_IDENTITY" "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built and signed: $app_path"
