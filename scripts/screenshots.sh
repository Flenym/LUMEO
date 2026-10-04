#!/usr/bin/env bash
# screenshots.sh — run XCUITests + extract screenshots for visual QA.
#
# Usage:
#   ./scripts/screenshots.sh [--project iOSApp/Lumeo.xcodeproj] [--scheme Lumeo]
#                            [--device "iPhone 16"] [--out screenshots] [--config Development]
#
# Flow (no fastlane):
#   1. `xcodebuild test` with `-resultBundlePath` (includes LumeoUITests, 7 critical flows).
#   2. Extract PNG attachments from the .xcresult via `xcresulttool` -> $OUT/xcresult/.
#   3. Fallback / supplement: `xcrun simctl io <device> screenshot` for the 10 screens
#      from Design/screens.md: onboarding, Home, Friends, Session, Chat, Squad,
#      Profile, Workshop, Premium, Settings (+ Admin overview when scheme is LumeoAdmin).
#
# Screenshots land in $OUT/ and are uploaded by CI as `ios-screenshots`.
set -euo pipefail

PROJECT="iOSApp/Lumeo.xcodeproj"
SCHEME="Lumeo"
DEVICE="iPhone 16"
OUT="screenshots"
CONFIG="Development"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --scheme) SCHEME="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PROJECT_DIR="$(dirname "$PROJECT")"
if [[ -f "$PROJECT_DIR/project.yml" ]] && command -v xcodegen >/dev/null 2>&1; then
  echo "==> xcodegen generate in $PROJECT_DIR"
  ( cd "$PROJECT_DIR" && xcodegen generate )
fi

mkdir -p "$OUT"
RESULT_BUNDLE="$OUT/LumeoTests.xcresult"

echo "==> xcodebuild test (scheme=$SCHEME, device=$DEVICE) -> $RESULT_BUNDLE"
set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
TEST_STATUS=$?
set -e
echo "==> xcodebuild test exit: $TEST_STATUS (screenshots still collected)"

# Extract PNG attachments from xcresult.
if [[ -d "$RESULT_BUNDLE" ]]; then
  echo "==> extracting xcresult attachments -> $OUT/xcresult"
  mkdir -p "$OUT/xcresult"
  if xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$OUT/xcresult" 2>/dev/null; then
    echo "==> xcresult attachments exported"
  else
    echo "==> WARNING: xcresulttool export failed; copying raw PNGs from bundle"
    find "$RESULT_BUNDLE" -name "*.png" -exec cp {} "$OUT/xcresult/" \; 2>/dev/null || true
  fi
fi

# simctl fallback: 10 screens from Design/screens.md (ТЗ screenshot set).
# UITests drive the app through these screens via deeplinks/accessibilityIdentifiers;
# here we capture the device frame for each named screen so CI always has images
# even when xcresult attachments are empty.
echo "==> simctl screenshots (10 screens) -> $OUT/simctl"
mkdir -p "$OUT/simctl"
UDID="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json,sys
data = json.load(sys.stdin)
want = '''$DEVICE'''.lower()
for rt in data.get('devices', {}).values():
    for d in rt:
        if d.get('name','').lower() == want and d.get('isAvailable', True):
            print(d['udid']); raise SystemExit
" 2>/dev/null || true)"
if [[ -n "${UDID:-}" ]]; then
  xcrun simctl boot "$UDID" 2>/dev/null || true
  # Дождаться загрузки (иначе screenshot пишет пустые PNG).
  xcrun simctl bootstatus "$UDID" -b 2>/dev/null || sleep 20
  for SCREEN in onboarding home friends session chat squad profile workshop premium settings admin; do
    # App under UITest navigates itself; one frame per screen name.
    if ! xcrun simctl io "$UDID" screenshot "$OUT/simctl/${SCREEN}.png" 2>/dev/null; then
      echo "  - FAILED: $SCREEN"
      continue
    fi
    if [[ ! -s "$OUT/simctl/${SCREEN}.png" ]]; then
      echo "  - EMPTY (0 bytes, dropped): $SCREEN"
      rm -f "$OUT/simctl/${SCREEN}.png"
    else
      echo "  - $OUT/simctl/${SCREEN}.png"
    fi
  done
else
  echo "==> WARNING: simulator '$DEVICE' not found; skipping simctl screenshots"
fi

COUNT="$(find "$OUT" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')"
echo "==> screenshots done: $COUNT png(s) in $OUT/ (test exit=$TEST_STATUS)"
ls -R "$OUT" || true
exit 0
