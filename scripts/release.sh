#!/bin/bash
# Release pipeline for CompHunt.
#
#   scripts/release.sh build      archive + export a Developer ID signed app
#   scripts/release.sh notarize   notarize + staple app, build DMG, notarize
#                                 + staple DMG (needs stored notarytool creds)
#
# Prereqs:
#   - "Developer ID Application" certificate in the login keychain
#   - notarytool credentials stored once via:
#       xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#         --apple-id <apple-id> --team-id V3P5U9Z68M --password <app-specific>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"
VERSION="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' "$ROOT/App/project.yml")"
BUILD_DIR="$ROOT/.release"
ARCHIVE="$BUILD_DIR/CompHunt.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/nCompHunt.app"
DMG="$BUILD_DIR/ncomphunt-$VERSION.dmg"

build() {
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"

  (cd "$ROOT/App" && xcodegen generate)
  xcodebuild -project "$ROOT/App/CompHunt.xcodeproj" -scheme CompHunt \
    -configuration Release -archivePath "$ARCHIVE" archive

  cat > "$BUILD_DIR/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>V3P5U9Z68M</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_DIR"

  codesign --verify --deep --strict --verbose=2 "$APP"
  echo "Built and signed: $APP"
}

notarize() {
  test -d "$APP" || { echo "run 'scripts/release.sh build' first" >&2; exit 1; }

  ditto -c -k --keepParent "$APP" "$BUILD_DIR/nCompHunt.zip"
  xcrun notarytool submit "$BUILD_DIR/nCompHunt.zip" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"

  STAGE="$BUILD_DIR/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "nCompHunt $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"

  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"

  spctl --assess --type open --context context:primary-signature -v "$DMG"
  echo "Notarized DMG: $DMG"
  shasum -a 256 "$DMG"
}

case "${1:-}" in
  build) build ;;
  notarize) notarize ;;
  *) echo "usage: scripts/release.sh {build|notarize}" >&2; exit 1 ;;
esac
