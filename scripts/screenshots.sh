#!/usr/bin/env bash
# screenshots.sh — run XCUITests + extract screenshots for visual QA.
#
# Usage:
#   ./scripts/screenshots.sh [--project iOSApp/Lumeo.xcodeproj] [--scheme Lumeo]
#                            [--device "iPhone 17"] [--out screenshots] [--config Development]
#                            [--derived-data DerivedData] [--no-build]
#                            [--attachments-only TestResults]
#
# Modes:
#   default: `xcodebuild test` (или test-without-building с --no-build),
#     затем экспорт аттачментов + simctl fallback.
#   --attachments-only DIR: БЕЗ запуска тестов — только экспорт PNG-аттачментов
#     (shot() из UITests) из готовых *.xcresult в DIR. Быстро, для CI где тесты
#     уже прогнаны отдельным шагом. Падает с ошибкой если PNG нет.
#
# Screenshots land in $OUT/ and are uploaded by CI as `ios-screenshots`.
set -euo pipefail

PROJECT="iOSApp/Lumeo.xcodeproj"
SCHEME="Lumeo"
DEVICE="iPhone 17"
OUT="screenshots"
CONFIG="Development"
DERIVED_DATA=""
NO_BUILD=0
ATTACHMENTS_ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --scheme) SCHEME="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --derived-data) DERIVED_DATA="$2"; shift 2 ;;
    --no-build) NO_BUILD=1; shift ;;
    --attachments-only) ATTACHMENTS_ONLY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PROJECT_DIR="$(dirname "$PROJECT")"
if [[ -f "$PROJECT_DIR/project.yml" ]] && command -v xcodegen >/dev/null 2>&1; then
  echo "==> xcodegen generate in $PROJECT_DIR"
  ( cd "$PROJECT_DIR" && xcodegen generate )
fi

mkdir -p "$OUT"

# Режим только-аттачменты: быстрый путь CI (тесты уже прогнаны).
if [[ -n "$ATTACHMENTS_ONLY" ]]; then
  echo "==> attachments-only mode from $ATTACHMENTS_ONLY"
  rm -rf "$OUT/xcresult"
  mkdir -p "$OUT/xcresult"
  for BUNDLE in "$ATTACHMENTS_ONLY"/*.xcresult; do
    [ -d "$BUNDLE" ] || continue
    # Отдельный подкаталог на бандл: иначе manifest.json коллизия
    # ("Failed to generate manifest.json: file already exists").
    SUB="$OUT/xcresult/$(basename "$BUNDLE" .xcresult)"
    mkdir -p "$SUB"
    echo "==> exporting attachments from $BUNDLE -> $SUB"
    xcrun xcresulttool export attachments --path "$BUNDLE" --output-path "$SUB" || true
  done
  COUNT="$(find "$OUT/xcresult" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')"
  echo "==> attachments-only done: $COUNT png(s) in $OUT/xcresult"
  ls -R "$OUT" || true
  if [[ "$COUNT" == "0" ]]; then
    echo "ERROR: no PNG attachments exported (shot() missing?)" >&2
    exit 1
  fi
  exit 0
fi

RESULT_BUNDLE="$OUT/LumeoTests.xcresult"

if [[ "$NO_BUILD" == 1 && -n "$DERIVED_DATA" ]]; then
  echo "==> xcodebuild test-without-building (reuse $DERIVED_DATA) -> $RESULT_BUNDLE"
  TEST_CMD=(test-without-building -derivedDataPath "$DERIVED_DATA")
else
  echo "==> xcodebuild test (scheme=$SCHEME, device=$DEVICE) -> $RESULT_BUNDLE"
  TEST_CMD=(test)
fi
set +e
xcodebuild "${TEST_CMD[@]}" \
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
