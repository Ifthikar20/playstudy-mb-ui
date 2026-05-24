#!/usr/bin/env bash
# Run the whole stack for local dev: Django backend (verbose) + Flutter app on
# the iOS Simulator, pointed at that backend. Ctrl+C stops both.
#
#   ./run-dev.sh
#
# Env overrides:
#   BACKEND_DIR=/path/to/ps-bk-dj   (default: ../ps-bk-dj)
#   API_BASE_URL=http://127.0.0.1:8000
set -euo pipefail
cd "$(dirname "$0")"
UI_DIR="$PWD"
BACKEND_DIR="${BACKEND_DIR:-$UI_DIR/../ps-bk-dj}"
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8000}"

if [[ ! -x "$BACKEND_DIR/setup.sh" ]]; then
  echo "ERROR: backend not found at $BACKEND_DIR — set BACKEND_DIR=/path/to/ps-bk-dj" >&2
  exit 1
fi

# --- 1. Backend: install deps (no server), then run it verbose in background.
echo "==> Preparing backend ($BACKEND_DIR)"
( cd "$BACKEND_DIR" && ./setup.sh --no-run )

echo "==> Starting backend (verbose) on 0.0.0.0:8000"
(
  cd "$BACKEND_DIR"
  # shellcheck disable=SC1091
  source .venv/bin/activate
  # --noreload keeps it a single process so cleanup kills it cleanly.
  exec env LOG_LEVEL=DEBUG python manage.py runserver 0.0.0.0:8000 --noreload
) &
BACKEND_PID=$!

cleanup() {
  echo
  echo "==> Stopping backend (pid $BACKEND_PID)"
  kill "$BACKEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "==> Waiting for backend health at $API_BASE_URL/health/"
for _ in $(seq 1 30); do
  if curl -sf "$API_BASE_URL/health/" >/dev/null 2>&1; then echo "    backend is up"; break; fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then echo "ERROR: backend exited during startup" >&2; exit 1; fi
  sleep 1
done

# --- 2. Flutter app on the iOS Simulator.
echo "==> Preparing Flutter app"
flutter pub get
if [[ ! -d ios ]]; then
  echo "    no ios/ platform folder — generating with 'flutter create .'"
  flutter create --platforms=ios,android .
fi

# Debug-only App Transport Security exception so the simulator can talk to the
# local http backend (loopback / .local). Idempotent.
PLIST="ios/Runner/Info.plist"
if [[ -f "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :NSAppTransportSecurity:NSAllowsLocalNetworking true" "$PLIST" 2>/dev/null || true
fi

echo "==> Booting iOS Simulator"
open -a Simulator || true
UDID=""
for _ in $(seq 1 30); do
  UDID="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  [[ -n "$UDID" ]] && break
  sleep 1
done

echo "==> Launching app (API_BASE_URL=$API_BASE_URL). Backend logs stream above; Ctrl+C stops everything."
if [[ -n "$UDID" ]]; then
  flutter run -d "$UDID" --dart-define=API_BASE_URL="$API_BASE_URL"
else
  echo "    (no booted simulator detected — letting Flutter pick a device)"
  flutter run --dart-define=API_BASE_URL="$API_BASE_URL"
fi
