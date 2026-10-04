#!/usr/bin/env bash
# build-unsigned-ipa.sh — assemble an UNSIGNED .ipa for CI artifacts / local inspection.
#
# Usage:
#   ./scripts/build-unsigned-ipa.sh --scheme SCHEME --project path/to/App.xcodeproj [--config Release] [--output out.ipa]
#   Params (env fallback): SCHEME / PROJECT / CONFIG / OUTPUT
#
# Behavior:
#   1. If a project.yml sits next to the .xcodeproj dir and `xcodegen` exists -> `xcodegen generate`.
#   2. `xcodebuild build-for-testing` smoke (CODE_SIGNING_ALLOWED=NO).
#   3. `xcodebuild archive` (CODE_SIGNING_ALLOWED=NO) -> find .app -> stage Payload/ -> zip .ipa.
#   4. Print path + size + SHA256 checksum.
#
# IMPORTANT: an unsigned .ipa can NOT be installed on a real iPhone.
# Real devices require a signed build (Developer ID / App Store / TestFlight).
# This script exists only for CI smoke-builds and artifact inspection.
set -euo pipefail

SCHEME="${SCHEME:-}"
PROJECT="${PROJECT:-}"
CONFIG="${CONFIG:-Release}"
OUTPUT="${OUTPUT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SCHEME" || -z "$PROJECT" ]]; then
  echo "Usage: $0 --scheme SCHEME --project PROJECT.xcodeproj [--config Release] [--output out.ipa]" >&2
  exit 1
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${SCHEME}-unsigned.ipa"
fi

# 1. XcodeGen step: <projectdir>/project.yml -> generate .xcodeproj when possible.
PROJECT_DIR="$(dirname "$PROJECT")"
if [[ -f "$PROJECT_DIR/project.yml" ]]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "==> xcodegen generate in $PROJECT_DIR"
    ( cd "$PROJECT_DIR" && xcodegen generate )
  else
    echo "==> WARNING: $PROJECT_DIR/project.yml found but xcodegen not installed; using existing $PROJECT"
  fi
fi

DESTINATION="${DESTINATION:-generic/platform=iOS}"

# 2. Smoke: build-for-testing (unsigned).
echo "==> xcodebuild build-for-testing: scheme=$SCHEME config=$CONFIG"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build-for-testing

# 3. Archive (unsigned) -> .app bundle.
ARCHIVE_PATH="$(mktemp -d)/app.xcarchive"
echo "==> xcodebuild archive (unsigned) -> $ARCHIVE_PATH"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 2 -name "*.app" 2>/dev/null | head -n 1 || true)"
if [[ -z "${APP_PATH:-}" ]]; then
  echo "ERROR: .app bundle not found under $ARCHIVE_PATH/Products/Applications" >&2
  exit 1
fi
echo "==> Found app: $APP_PATH"

# 4. Stage Payload/ + zip.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP_PATH" "$STAGE/Payload/"

# NOTE: unsigned — no codesign step on purpose. Will NOT install on a real iPhone.
rm -f "$OUTPUT"
( cd "$STAGE" && zip -qr "$OLDPWD/$OUTPUT" Payload )

SIZE="$(wc -c < "$OUTPUT" | tr -d ' ')"
echo "==> Unsigned IPA: $OUTPUT (${SIZE} bytes)"
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$OUTPUT"
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$OUTPUT"
fi
echo "WARNING: this IPA is _unsigned and cannot be installed on a physical iPhone without signing."
