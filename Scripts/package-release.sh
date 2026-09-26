#!/bin/zsh
# Build, notarize and staple a Developer ID release. Credentials stay in Keychain.
set -euo pipefail

cd "${0:A:h:h}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool Keychain profile}"
[[ "$(uname -m)" == arm64 ]] || { print -u2 'Release target is Apple Silicon.'; exit 1; }

./Scripts/build-release.sh
APP_SOURCE="build/Build/Products/Release/UTUVO Explain.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_SOURCE/Contents/Info.plist")
OUTPUT="$PWD/build/distribution/$VERSION"
STEM="UTUVO-Explain-$VERSION-arm64"
[[ ! -e "$OUTPUT/$STEM.dmg" ]] || { print -u2 'Release DMG already exists; use a new version or preserve this release.'; exit 1; }
mkdir -p "$OUTPUT/work/content"

APP="$OUTPUT/work/UTUVO Explain.app"
ditto "$APP_SOURCE" "$APP"
lipo -verify_arch arm64 "$APP/Contents/MacOS/UTUVO Explain"
codesign --verify --deep --strict "$APP"

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$2"
  /usr/bin/python3 - "$2" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Apple notarization:', result.get('id'), result.get('status'))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; inspect the saved result.')
PY
}

ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/work/app-submission.zip"
notarize "$OUTPUT/work/app-submission.zip" "$OUTPUT/app-notarization.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

ditto "$APP" "$OUTPUT/work/content/UTUVO Explain.app"
ln -s /Applications "$OUTPUT/work/content/Applications"
cat > "$OUTPUT/work/content/安裝說明.txt" <<'TXT'
UTUVO Explain · 貓貓翻譯家

把 UTUVO Explain 拖到 Applications，從「應用程式」啟動。
首次開啟，在設定貼上自己的 Gemini API Key，並允許 macOS 的「裝置控制和資料取用」權限。
選字後按 ⌥D 看白話解釋；按 ⌥⇧D 翻譯。也可以在視窗內手動貼字。
圖片、影片裡的字：按 ⌥S 框選後解釋，⌥⇧S 框選後翻譯（第一次需允許「螢幕與系統錄音」）。
第一次開啟會出現使用教學，之後可從選單列「使用教學…」再打開。

Requires macOS 14+ and Apple Silicon. A personal Gemini API key and internet connection are required.
TXT
hdiutil create -quiet -fs HFS+ -volname 'UTUVO Explain' -srcfolder "$OUTPUT/work/content" \
  -format UDZO -imagekey zlib-level=9 "$OUTPUT/$STEM.dmg"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$OUTPUT/$STEM.dmg"
codesign --verify --strict "$OUTPUT/$STEM.dmg"
notarize "$OUTPUT/$STEM.dmg" "$OUTPUT/dmg-notarization.json"
xcrun stapler staple "$OUTPUT/$STEM.dmg"
xcrun stapler validate "$OUTPUT/$STEM.dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$OUTPUT/$STEM.dmg"

(cd "$OUTPUT" && shasum -a 256 "$STEM.dmg" > SHA256SUMS.txt)
print "Verified release: $OUTPUT/$STEM.dmg"
