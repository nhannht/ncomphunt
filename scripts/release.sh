#!/bin/bash
# Release pipeline for CompHunt.
#
#   scripts/release.sh build      archive + export a Developer ID signed app
#   scripts/release.sh notarize   notarize + staple app, build DMG, notarize
#                                 + staple DMG (needs stored notarytool creds)
#   scripts/release.sh appstore   archive with Mac App Store signing and upload
#                                 to App Store Connect (or export a .pkg for
#                                 Transporter when no ASC API key is set)
#
# Prereqs:
#   - "Developer ID Application" certificate in the login keychain
#   - notarytool credentials stored once via:
#       xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#         --apple-id <apple-id> --team-id V3P5U9Z68M --password <app-specific>
#   - appstore lane: an App Store Connect API key (App Manager role) exported as
#       ASC_KEY_P8 (path to the .p8), ASC_KEY_ID, ASC_ISSUER_ID
#     Without all three, the lane exports a signed .pkg to upload manually with
#     Transporter.app instead of uploading directly.
set -Eeuo pipefail
# Any UNGUARDED failure aborts loudly with the line number (set -E makes the
# ERR trap fire inside functions too). Guarded steps print their own FATAL line.
trap 'echo "release.sh: aborted (exit $?) near line ${LINENO}" >&2' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"
# head -n1: app and widget targets both carry MARKETING_VERSION (same value).
VERSION="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' "$ROOT/App/project.yml" | head -n1)"
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

# --- notarization helpers -------------------------------------------------
# Submit ONE file and block until Apple returns a terminal verdict.
# Root-cause fixes over the old `submit --wait`:
#   * no --wait: submit returns only after the upload completes, so a clean
#     exit means the bytes actually landed. The old failure printed a
#     submission id BEFORE the upload, then the upload died, leaving a phantom
#     id that later got garbage-collected (never Accepted, never Invalid).
#   * caffeinate -i: idle sleep cannot interrupt the upload mid-flight (the
#     concrete trigger last time - the Mac slept during the DMG upload).
#   * the id is verified against the live submission record before we trust it.
notarize_file() {
  local file="$1" label="$2" out id
  echo ">>> submitting $label ($file) for notarization ..."
  if ! out="$(caffeinate -i xcrun notarytool submit "$file" \
              --keychain-profile "$NOTARY_PROFILE" 2>&1)"; then
    echo "FATAL: notarytool submit failed for $label (upload did not complete):" >&2
    echo "$out" >&2
    exit 1
  fi
  echo "$out"
  id="$(printf '%s\n' "$out" | awk -F': ' '/^ *id:/ {print $2; exit}')"
  [ -n "$id" ] || { echo "FATAL: could not parse submission id for $label" >&2; echo "$out" >&2; exit 1; }
  poll_notarization "$id" "$label"
}

# Poll a submission id to a terminal state. Distinguishes EVERY outcome so the
# script can never hang on a dead id (the bug that wasted a day):
#   Accepted          -> return
#   Invalid/Rejected  -> dump the notarization log, fail
#   does not exist    -> upload never registered, or was swept; fail, never wait
#   keychain locked   -> fail with the exact unlock command
#   In Progress       -> keep polling, up to the hard cap, then fail loudly
poll_notarization() {
  local id="$1" label="$2" info status now
  local hard_cap=$(( $(date +%s) + 2400 ))   # 40-min ceiling, then fail (no hanging)
  local grace=$(( $(date +%s) + 120 ))       # tolerate 2 min of record propagation
  local registered=0
  echo ">>> polling $label verdict (id $id) ..."
  while :; do
    now="$(date +%s)"
    if [ "$now" -gt "$hard_cap" ]; then
      echo "FATAL: $label ($id) returned no verdict within 40min." >&2
      echo "  Inspect: xcrun notarytool info $id --keychain-profile $NOTARY_PROFILE" >&2
      exit 1
    fi
    info="$(xcrun notarytool info "$id" --keychain-profile "$NOTARY_PROFILE" 2>&1 || true)"
    if printf '%s' "$info" | grep -qi 'No Keychain password item'; then
      echo "FATAL: keychain locked mid-poll. Unlock and re-run notarize:" >&2
      echo "  security unlock-keychain ~/Library/Keychains/login.keychain-db" >&2
      exit 1
    fi
    if printf '%s' "$info" | grep -qi 'does not exist'; then
      if [ "$registered" -eq 1 ]; then
        echo "FATAL: $label ($id) registered then vanished - Apple swept an incomplete upload. Re-run notarize." >&2
        exit 1
      fi
      if [ "$now" -gt "$grace" ]; then
        echo "FATAL: $label ($id) never registered within 2min of submit - the upload did not land." >&2
        echo "  Do NOT wait on this id. Re-run notarize." >&2
        exit 1
      fi
      sleep 10; continue
    fi
    registered=1
    status="$(printf '%s\n' "$info" | awk -F': ' '/status:/ {print $2; exit}')"
    case "$status" in
      Accepted) echo "$label Accepted ($id)."; return 0 ;;
      Invalid|Rejected)
        echo "FATAL: $label $status ($id). Notarization log:" >&2
        xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        exit 1 ;;
      *) sleep 20 ;;   # In Progress (or a transient blank) - keep waiting
    esac
  done
}

# Staple a ticket and PROVE it took. Never report success without validating.
staple_and_verify() {
  local file="$1" label="$2"
  xcrun stapler staple "$file"   || { echo "FATAL: stapler staple failed for $label" >&2; exit 1; }
  xcrun stapler validate "$file" || { echo "FATAL: stapler validate failed for $label after stapling" >&2; exit 1; }
  echo "$label stapled + validated."
}

notarize() {
  test -d "$APP" || { echo "FATAL: run 'scripts/release.sh build' first ($APP missing)" >&2; exit 1; }

  # 1. notarize + staple the app itself
  rm -f "$BUILD_DIR/nCompHunt.zip"
  ditto -c -k --keepParent "$APP" "$BUILD_DIR/nCompHunt.zip"
  notarize_file "$BUILD_DIR/nCompHunt.zip" "app"
  staple_and_verify "$APP" "app"

  # 2. build the DMG around the stapled app
  STAGE="$BUILD_DIR/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"
  hdiutil create -volname "nCompHunt $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"

  # 3. notarize + staple the DMG container (v0.1.0 parity)
  notarize_file "$DMG" "dmg"
  staple_and_verify "$DMG" "dmg"

  # 4. final gate. spctl on the .dmg container is advisory: the DMG is not
  #    codesigned, so it can report "rejected" even when notarized+stapled;
  #    Gatekeeper assesses the app inside, which passes. Non-fatal.
  if ! spctl --assess --type open --context context:primary-signature -v "$DMG"; then
    echo "NOTE: spctl on the .dmg container is advisory (app inside is notarized+stapled)."
  fi
  echo "Notarized + stapled DMG: $DMG"
  shasum -a 256 "$DMG"
}

# --- Mac App Store lane -----------------------------------------------------
# Separate archive + export dirs so DMG artifacts are never clobbered. Signing
# is AUTOMATIC here (overrides the manual Developer ID settings in project.yml):
# with -allowProvisioningUpdates, xcodebuild creates/fetches the Apple
# Distribution + Mac Installer Distribution certs and the MAS provisioning
# profiles for both bundle ids. caffeinate for the same reason as notarize:
# idle sleep once killed an upload mid-flight.
appstore() {
  local mas_dir="$BUILD_DIR/appstore"
  local mas_archive="$mas_dir/CompHunt-mas.xcarchive"
  local mas_export="$mas_dir/export"
  local auth_flags=()
  local destination="upload"

  if [ -n "${ASC_KEY_P8:-}" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
    test -f "$ASC_KEY_P8" || { echo "FATAL: ASC_KEY_P8 ($ASC_KEY_P8) not found" >&2; exit 1; }
    auth_flags=(-authenticationKeyPath "$ASC_KEY_P8"
                -authenticationKeyID "$ASC_KEY_ID"
                -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  else
    destination="export"
    echo "NOTE: ASC_KEY_P8/ASC_KEY_ID/ASC_ISSUER_ID not all set."
    echo "      Exporting a .pkg to upload manually with Transporter.app."
    echo "      (automatic signing then relies on the Apple ID session in Xcode)"
  fi

  rm -rf "$mas_dir"
  mkdir -p "$mas_dir"

  (cd "$ROOT/App" && xcodegen generate)
  xcodebuild -project "$ROOT/App/CompHunt.xcodeproj" -scheme CompHunt \
    -configuration Release -archivePath "$mas_archive" archive \
    CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM=V3P5U9Z68M \
    -allowProvisioningUpdates ${auth_flags[@]+"${auth_flags[@]}"}

  cat > "$mas_dir/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>V3P5U9Z68M</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>$destination</string>
</dict>
</plist>
PLIST

  caffeinate -i xcodebuild -exportArchive -archivePath "$mas_archive" \
    -exportOptionsPlist "$mas_dir/ExportOptions.plist" \
    -exportPath "$mas_export" \
    -allowProvisioningUpdates ${auth_flags[@]+"${auth_flags[@]}"}

  if [ "$destination" = "upload" ]; then
    echo "Uploaded $VERSION (build from $mas_archive) to App Store Connect."
    echo "Track processing in ASC > TestFlight/Builds; attach to the version when Ready."
  else
    echo "Exported for manual upload:"
    ls -l "$mas_export"
    echo "Open Transporter.app and deliver the .pkg above."
  fi
}

case "${1:-}" in
  build) build ;;
  notarize) notarize ;;
  appstore) appstore ;;
  *) echo "usage: scripts/release.sh {build|notarize|appstore}" >&2; exit 1 ;;
esac
