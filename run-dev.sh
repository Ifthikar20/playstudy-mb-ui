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
# Prefix every backend line with [backend] so it's distinguishable from the
# Flutter app logs in the shared terminal (awk fflush = line-buffered).
(
  cd "$BACKEND_DIR"
  # shellcheck disable=SC1091
  source .venv/bin/activate
  # --noreload keeps it a single process so cleanup kills it cleanly.
  exec env LOG_LEVEL=DEBUG python manage.py runserver 0.0.0.0:8000 --noreload
) > >(awk '{ print "[backend] " $0; fflush() }') 2>&1 &
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

SIM_NAME="${SIM_NAME:-iPhone 15}"
# Set DEVICE to a physical device id/name (or 'auto') to run on a real iPhone
# instead of the simulator, e.g.  DEVICE=auto ./run-dev.sh
DEVICE="${DEVICE:-}"

TARGET_ID=""
if [[ -n "$DEVICE" ]]; then
  # --- Physical device path -------------------------------------------------
  if [[ "$DEVICE" == "auto" ]]; then
    TARGET_ID="$(flutter devices --machine 2>/dev/null | python3 -c "import sys,json
try: ds=json.load(sys.stdin)
except Exception: ds=[]
ios=[d for d in ds if 'ios' in (d.get('targetPlatform') or '') and not d.get('emulator')]
print(ios[0]['id'] if ios else '')" 2>/dev/null || true)"
    if [[ -z "$TARGET_ID" ]]; then
      echo "ERROR: no physical iOS device found. Unlock your iPhone, keep it on" >&2
      echo "the same Wi-Fi/cable, and make sure it's paired in Xcode." >&2
      exit 1
    fi
  else
    TARGET_ID="$DEVICE"
  fi
  # The phone can't reach the Mac via localhost — use the Mac's LAN IP.
  if [[ "$API_BASE_URL" == "http://127.0.0.1:"* || "$API_BASE_URL" == "http://localhost:"* ]]; then
    LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
    if [[ -n "$LAN_IP" ]]; then
      API_BASE_URL="http://$LAN_IP:8000"
    else
      echo "WARNING: couldn't detect a LAN IP; the phone may not reach the backend." >&2
    fi
  fi
  echo "==> Target: physical device '$TARGET_ID' (API_BASE_URL=$API_BASE_URL)"
else
  # --- Simulator path (default) --------------------------------------------
  echo "==> Booting iOS Simulator ($SIM_NAME)"
  TARGET_ID="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
  if [[ -z "$TARGET_ID" ]]; then
    TARGET_ID="$(xcrun simctl list devices available 2>/dev/null | grep -F "$SIM_NAME (" | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
    [[ -z "$TARGET_ID" ]] && TARGET_ID="$(xcrun simctl list devices available 2>/dev/null | grep -E 'iPhone' | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
    if [[ -z "$TARGET_ID" ]]; then
      echo "ERROR: no iOS Simulator available (install one via Xcode > Settings > Components)." >&2
      exit 1
    fi
    echo "    booting simulator $TARGET_ID"
    xcrun simctl boot "$TARGET_ID" 2>/dev/null || true
  fi
  open -a Simulator || true
  for _ in $(seq 1 60); do
    if xcrun simctl list devices | grep "$TARGET_ID" | grep -q 'Booted'; then break; fi
    sleep 1
  done
fi

echo "==> Launching app on $TARGET_ID (auto-login $DEV_EMAIL). Ctrl+C stops everything."
flutter run -d "$TARGET_ID" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=DEV_EMAIL="$DEV_EMAIL" \
  --dart-define=DEV_PASSWORD="$DEV_PASSWORD"
