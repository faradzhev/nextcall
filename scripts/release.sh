#!/usr/bin/env bash
#
# Builds, signs, notarizes and packages NextCall for direct distribution:
#   Release archive -> Developer ID export -> notarize + staple the app -> DMG (signed, notarized, stapled)
#   -> Sparkle appcast entry (EdDSA-signed).
#
# Configuration comes from the environment; nothing secret is stored in the repository.
#
#   DEVELOPER_ID_APPLICATION  Signing identity, e.g. "Developer ID Application: Jane Doe (ABCDE12345)"
#   NOTARY_PROFILE            notarytool keychain profile (xcrun notarytool store-credentials <name> ...)
#   SPARKLE_PUBLIC_ED_KEY     Public EdDSA key printed by Sparkle's generate_keys; built into the app
#   SPARKLE_FEED_URL          Where the appcast will be hosted, e.g. https://example.com/nextcall/appcast.xml
#   DOWNLOAD_URL_PREFIX       Where the DMGs will be hosted, e.g. https://example.com/nextcall/releases/
#
# Optional:
#   SPARKLE_PRIVATE_KEY_FILE  EdDSA private key file for signing the appcast (default: the login keychain)
#   SPARKLE_BIN               Directory with Sparkle's generate_appcast (default: found in DerivedData)
#   BUILD_NUMBER              CFBundleVersion override (default: CURRENT_PROJECT_VERSION from project.yml)
#   OUTPUT_DIR                Where results go (default: dist)
#
# Flags:
#   --local        Ad-hoc sign and skip notarization, stapling and the appcast: a package you can inspect
#                  on this Mac without any credentials. Not distributable.
#   --dry-run      Print the commands instead of running them.
#   --skip-tests   Skip the unit-test and localization gates.
#
# Set SMOKE_TEST=1 to also launch the finished app for a few seconds (always done with --local).
#   --help         Show this text.

set -euo pipefail

cd "$(dirname "$0")/.."

LOCAL=0
DRY_RUN=0
SKIP_TESTS=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --help | -h) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)" >&2; exit 64 ;;
  esac
done

OUTPUT_DIR="${OUTPUT_DIR:-dist}"
BUILD_DIR="$OUTPUT_DIR/build"
ARCHIVE="$BUILD_DIR/NextCall.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
RELEASES_DIR="$OUTPUT_DIR/releases"

log() { printf '\n==> %s\n' "$*"; }
fail() { echo "error: $*" >&2; exit 1; }

# Runs a command, or only prints it with --dry-run.
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '+ '; printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

require_env() {
  local missing=()
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || missing+=("$name")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: missing environment variable(s): ${missing[*]}" >&2
    echo "       see ./scripts/release.sh --help, or use --local for an unsigned test package." >&2
    exit 78
  fi
}

# --- Configuration ----------------------------------------------------------------------------------------

if [[ $LOCAL -eq 1 ]]; then
  IDENTITY="-"
  TEAM=""
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
else
  require_env DEVELOPER_ID_APPLICATION NOTARY_PROFILE SPARKLE_PUBLIC_ED_KEY SPARKLE_FEED_URL DOWNLOAD_URL_PREFIX
  IDENTITY="$DEVELOPER_ID_APPLICATION"
  # "Developer ID Application: Name (TEAMID)" -> TEAMID
  TEAM="$(sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p' <<<"$IDENTITY")"
  [[ -n "$TEAM" ]] || fail "could not read the team ID from DEVELOPER_ID_APPLICATION ('$IDENTITY')"
fi

command -v xcodegen >/dev/null || fail "xcodegen is required (brew install xcodegen)"
command -v xcodebuild >/dev/null || fail "xcodebuild is required (install Xcode)"

# --- Gates ------------------------------------------------------------------------------------------------

log "Generating the Xcode project"
run xcodegen generate

if [[ $SKIP_TESTS -eq 0 ]]; then
  log "Running unit tests"
  run xcodebuild -scheme NextCall -destination 'platform=macOS' test -only-testing:NextCallCoreTests
  log "Checking localization"
  run python3 scripts/check_localization.py
fi

# --- Archive ----------------------------------------------------------------------------------------------

BUILD_SETTINGS=(
  "SPARKLE_FEED_URL=${SPARKLE_FEED_URL:-}"
  "SPARKLE_PUBLIC_ED_KEY=${SPARKLE_PUBLIC_ED_KEY:-}"
)
[[ -z "${BUILD_NUMBER:-}" ]] || BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")

SIGN_SETTINGS=("CODE_SIGN_IDENTITY=$IDENTITY" "ENABLE_HARDENED_RUNTIME=YES")
if [[ $LOCAL -eq 0 ]]; then
  SIGN_SETTINGS+=("CODE_SIGN_STYLE=Manual" "DEVELOPMENT_TEAM=$TEAM" "OTHER_CODE_SIGN_FLAGS=--timestamp")
fi

log "Archiving (Release, universal)"
run rm -rf "$BUILD_DIR"
run mkdir -p "$BUILD_DIR" "$RELEASES_DIR"

if [[ $LOCAL -eq 1 ]]; then
  # An ad-hoc signed app has no Team ID, so under the hardened runtime it refuses to load its own embedded
  # frameworks ("different Team IDs") and dies at launch. A Developer ID build shares one Team ID and needs
  # no exception, so this relaxation exists only in --local packages.
  LOCAL_ENTITLEMENTS="$PWD/$BUILD_DIR/NextCall-local.entitlements"
  run cp App/NextCall.entitlements "$LOCAL_ENTITLEMENTS"
  run /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$LOCAL_ENTITLEMENTS"
  SIGN_SETTINGS+=("CODE_SIGN_ENTITLEMENTS=$LOCAL_ENTITLEMENTS")
fi

run xcodebuild archive \
  -project NextCall.xcodeproj -scheme NextCall -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
  "${SIGN_SETTINGS[@]}" "${BUILD_SETTINGS[@]}"

if [[ $LOCAL -eq 1 ]]; then
  APP="$ARCHIVE/Products/Applications/NextCall.app"
else
  log "Exporting with Developer ID"
  EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
  if [[ $DRY_RUN -eq 0 ]]; then
    cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$IDENTITY</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
  fi
  run xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" -exportOptionsPlist "$EXPORT_OPTIONS"
  APP="$EXPORT_DIR/NextCall.app"
fi

# --- Verify -----------------------------------------------------------------------------------------------

if [[ $DRY_RUN -eq 0 ]]; then
  log "Verifying the build"
  [[ -d "$APP" ]] || fail "expected app not found at $APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
  ARCHS="$(lipo -archs "$APP/Contents/MacOS/NextCall")"
  [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || fail "binary is not universal (found: $ARCHS)"
  # Capture first: `grep -q` closing the pipe early would trip `pipefail` on codesign's SIGPIPE.
  SIGNATURE="$(codesign -dv "$APP" 2>&1)"
  [[ "$SIGNATURE" == *"flags="*runtime* ]] || fail "hardened runtime is not enabled"
  ENTITLEMENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
  [[ "$ENTITLEMENTS" == *com.apple.security.app-sandbox* ]] || fail "app sandbox entitlement missing"
  echo "universal ($ARCHS), hardened runtime on, sandboxed"
  if [[ $LOCAL -eq 1 || "${SMOKE_TEST:-0}" == 1 ]]; then
    # Catches packaging mistakes that only show at launch (missing or unloadable frameworks).
    # The app may show its welcome window for a few seconds.
    log "Smoke test: launching the app"
    "$APP/Contents/MacOS/NextCall" >/dev/null 2>&1 &
    SMOKE_PID=$!
    sleep 4
    if kill -0 "$SMOKE_PID" 2>/dev/null; then
      kill "$SMOKE_PID"; wait "$SMOKE_PID" 2>/dev/null || true
      echo "launches and keeps running"
    else
      fail "the app exited right after launch; see ~/Library/Logs/DiagnosticReports"
    fi
  fi
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
  BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
else
  VERSION="X.Y.Z"; BUILD="N"
fi
DMG="$RELEASES_DIR/NextCall-$VERSION.dmg"
echo "Version $VERSION (build $BUILD)"

notarize() { # notarize <file>
  local file="$1" result status id
  result="$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  status="$(/usr/bin/plutil -extract status raw -o - - <<<"$result")"
  id="$(/usr/bin/plutil -extract id raw -o - - <<<"$result")"
  if [[ "$status" != "Accepted" ]]; then
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fail "notarization of $(basename "$file") finished with status '$status'"
  fi
}

# --- Notarize and staple the app --------------------------------------------------------------------------

if [[ $LOCAL -eq 0 ]]; then
  log "Notarizing the app"
  run ditto -c -k --keepParent "$APP" "$BUILD_DIR/NextCall.zip"
  if [[ $DRY_RUN -eq 1 ]]; then echo "+ notarize $BUILD_DIR/NextCall.zip"; else notarize "$BUILD_DIR/NextCall.zip"; fi
  run xcrun stapler staple "$APP"
  run xcrun stapler validate "$APP"
  run spctl --assess --type execute --verbose=2 "$APP"
fi

# --- DMG --------------------------------------------------------------------------------------------------

log "Creating the DMG"
STAGING="$BUILD_DIR/dmg"
run rm -rf "$STAGING"
run mkdir -p "$STAGING"
run ditto "$APP" "$STAGING/NextCall.app"
run ln -s /Applications "$STAGING/Applications"
# MIT and the bundled packages require their notices to travel with the binary.
run cp LICENSE THIRD_PARTY_NOTICES.md "$STAGING/"
run rm -f "$DMG"
run hdiutil create -volname "NextCall" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"

if [[ $LOCAL -eq 0 ]]; then
  log "Signing and notarizing the DMG"
  run codesign --sign "$IDENTITY" --timestamp "$DMG"
  if [[ $DRY_RUN -eq 1 ]]; then echo "+ notarize $DMG"; else notarize "$DMG"; fi
  run xcrun stapler staple "$DMG"
  run xcrun stapler validate "$DMG"
fi

# --- Sparkle appcast --------------------------------------------------------------------------------------

find_generate_appcast() {
  if [[ -n "${SPARKLE_BIN:-}" ]]; then echo "$SPARKLE_BIN/generate_appcast"; return; fi
  find "$HOME/Library/Developer/Xcode/DerivedData" -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -n 1
}

if [[ $LOCAL -eq 1 && -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  log "Skipping the appcast (--local without SPARKLE_PRIVATE_KEY_FILE)"
else
  log "Generating the Sparkle appcast"
  GENERATE_APPCAST="$(find_generate_appcast)"
  [[ $DRY_RUN -eq 1 || -x "$GENERATE_APPCAST" ]] || fail "generate_appcast not found; build the app once so Sparkle is fetched, or set SPARKLE_BIN"
  APPCAST_ARGS=(--download-url-prefix "${DOWNLOAD_URL_PREFIX:-https://example.invalid/releases/}" -o "$OUTPUT_DIR/appcast.xml")
  [[ -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]] || APPCAST_ARGS+=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
  # Every DMG kept in releases/ stays in the feed, so older versions can still update.
  run "${GENERATE_APPCAST:-generate_appcast}" "${APPCAST_ARGS[@]}" "$RELEASES_DIR"
fi

log "Done"
echo "App:     $APP"
echo "DMG:     $DMG"
[[ ! -f "$OUTPUT_DIR/appcast.xml" ]] || echo "Appcast: $OUTPUT_DIR/appcast.xml (upload it to $SPARKLE_FEED_URL)"
