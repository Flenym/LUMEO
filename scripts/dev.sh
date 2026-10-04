#!/usr/bin/env bash
# dev.sh — one-command local dev: backend on :5267 + iOS hints.
#
# Usage: ./scripts/dev.sh
set -euo pipefail

echo "==> Lumeo dev"
echo "    backend : http://localhost:5267 (PORT=5267)"
echo "    iOS     : open generated .xcodeproj after xcodegen (see below)"
echo ""

if [[ ! -f .env ]]; then
  echo "NOTE: .env missing — copy placeholders first: cp .env.example .env"
fi

# Backend in background (foreground with Ctrl+C kills both via trap).
npm --workspace Backend run dev &
BACKEND_PID=$!
trap 'kill $BACKEND_PID 2>/dev/null || true' EXIT

echo ""
echo "iOS (separate terminal):"
echo "  cd iOSApp && xcodegen generate && open Lumeo.xcodeproj   # scheme Lumeo, config Development"
echo "  cd AdminApp && xcodegen generate && open LumeoAdmin.xcodeproj"
echo "API_BASE_URL dev = http://localhost:5267 (iOSApp/Config/Development.xcconfig)"
echo ""
echo "==> backend starting (PID $BACKEND_PID) — press Ctrl+C to stop"
wait $BACKEND_PID
