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
# Dev account the app auto-logs-in with (override via env).
DEV_EMAIL="${DEV_EMAIL:-dev@playstudy.app}"
DEV_PASSWORD="${DEV_PASSWORD:-Devpass123!}"

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

# --- 1b. Ensure the dev account exists (auth/email registers-or-logs-in).
echo "==> Ensuring dev login ($DEV_EMAIL)"
if curl -sf -X POST "$API_BASE_URL/api/v1/auth/email/" \
     -H 'Content-Type: application/json' \
     -d "{\"email\":\"$DEV_EMAIL\",\"password\":\"$DEV_PASSWORD\",\"name\":\"Dev\"}" \
     >/dev/null 2>&1; then
  echo "    dev account ready — app will auto-login"
else
  echo "    WARNING: could not register/login dev account (wrong password for an" >&2
  echo "    existing account, or weak password). App will show the login screen." >&2
fi

# --- 2. Flutter app on the iOS Simulator.
echo "==> Preparing Flutter app"
flutter pub get
# Check for the actual Xcode project, not just the ios/ folder — a partial
# ios/ (e.g. only Info.plist) still needs regeneration.
if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  echo "    iOS project missing/incomplete — running 'flutter create --platforms=ios .'"
  flutter create --platforms=ios .
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
# Use an already-booted simulator, else boot an available iPhone. We pin to a
# simulator UDID so Flutter never falls back to a physical device (which would
# require Apple code-signing).
UDID="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available 2>/dev/null \
            | grep -E 'iPhone' | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [[ -n "$UDID" ]]; then
    echo "    booting simulator $UDID"
    xcrun simctl boot "$UDID" 2>/dev/null || true
  fi
fi
open -a Simulator || true

if [[ -z "$UDID" ]]; then
  cat >&2 <<'MSG'
    ERROR: no iOS Simulator available. Install one in Xcode:
        Xcode > Settings > Components (or Platforms) > iOS Simulator
    Then re-run ./run-dev.sh
MSG
  exit 1
fi

# Wait until the chosen simulator is actually Booted.
for _ in $(seq 1 60); do
  if xcrun simctl list devices | grep "$UDID" | grep -q 'Booted'; then break; fi
  sleep 1
done

echo "==> Launching app on simulator $UDID (API_BASE_URL=$API_BASE_URL, auto-login $DEV_EMAIL). Ctrl+C stops everything."
flutter run -d "$UDID" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=DEV_EMAIL="$DEV_EMAIL" \
  --dart-define=DEV_PASSWORD="$DEV_PASSWORD"
