#!/usr/bin/env bash
# Production-style run: builds a RELEASE build and installs it on your iPhone.
#
#   ./run-prod.sh                      # real production (api/games defaults, real sign-in)
#   WITH_BACKEND=1 ./run-prod.sh       # release build + LOCAL backend & games on your
#                                      # Mac + auto-login (a usable installed app for testing)
#   DEVICE=auto ./run-prod.sh
#
# Notes:
#  - WITH_BACKEND runs the backend on your Mac, so keep this terminal open while
#    you use the app (the standalone app can't reach it once the script stops).
#  - For a truly standalone app with no Mac, deploy the backend to the
#    production URLs and run without WITH_BACKEND (real sign-in).
set -euo pipefail
cd "$(dirname "$0")"
UI_DIR="$PWD"

DEVICE="${DEVICE-AliIphone2024}"
API_BASE_URL="${API_BASE_URL:-}"
GAMES_BASE_URL="${GAMES_BASE_URL:-}"
DEV_EMAIL="${DEV_EMAIL:-}"
DEV_PASSWORD="${DEV_PASSWORD:-}"

WITH_BACKEND="${WITH_BACKEND:-}"
BACKEND_DIR="${BACKEND_DIR:-$UI_DIR/../ps-bk-dj}"
LANDING_DIR="${LANDING_DIR:-$UI_DIR/../playstudy-mb-landing}"
GAMES_PORT="${GAMES_PORT:-8080}"

# --- Resolve the target device (must be a real device for an install) --------
TARGET_ID=""
if [[ "$DEVICE" == "auto" ]]; then
  TARGET_ID="$(flutter devices --machine 2>/dev/null | python3 -c "import sys,json
try: ds=json.load(sys.stdin)
except Exception: ds=[]
ios=[d for d in ds if 'ios' in (d.get('targetPlatform') or '') and not d.get('emulator')]
print(ios[0]['id'] if ios else '')" 2>/dev/null || true)"
  if [[ -z "$TARGET_ID" ]]; then
    echo "ERROR: no physical iOS device found. Unlock your iPhone and pair it in Xcode." >&2
    exit 1
  fi
else
  TARGET_ID="$DEVICE"
fi

BACKEND_PID=""
GAMES_PID=""
cleanup() {
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  [[ -n "$GAMES_PID" ]] && kill "$GAMES_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Optional: run the backend + games locally and auto-login ----------------
if [[ -n "$WITH_BACKEND" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
  API_BASE_URL="${API_BASE_URL:-http://$LAN_IP:8000}"
  GAMES_BASE_URL="${GAMES_BASE_URL:-http://$LAN_IP:$GAMES_PORT}"
  DEV_EMAIL="${DEV_EMAIL:-dev@playstudy.app}"
  DEV_PASSWORD="${DEV_PASSWORD:-Devpass123!}"

  if [[ ! -x "$BACKEND_DIR/setup.sh" ]]; then
    echo "ERROR: backend not found at $BACKEND_DIR — set BACKEND_DIR=..." >&2
    exit 1
  fi
  echo "==> Preparing backend (installs deps + runs migrations)"
  ( cd "$BACKEND_DIR" && ./setup.sh --no-run )

  echo "==> Starting backend on 0.0.0.0:8000"
  (
    cd "$BACKEND_DIR"
    # shellcheck disable=SC1091
    source .venv/bin/activate
    unset ANTHROPIC_API_KEY ANTHROPIC_MODEL LLM_PROVIDER \
          DEEPSEEK_API_KEY GEMINI_API_KEY LOCAL_LLM_API_KEY 2>/dev/null || true
    exec python manage.py runserver 0.0.0.0:8000 --noreload
  ) > >(awk '{ print "[backend] " $0; fflush() }') 2>&1 &
  BACKEND_PID=$!

  if [[ -d "$LANDING_DIR/public/games" ]]; then
    echo "==> Serving games from $LANDING_DIR/public on :$GAMES_PORT"
    ( cd "$LANDING_DIR/public" && exec python3 -m http.server "$GAMES_PORT" --bind 0.0.0.0 ) \
      > >(awk '{ print "[games] " $0; fflush() }') 2>&1 &
    GAMES_PID=$!
  fi

  echo "==> Waiting for backend health at $API_BASE_URL/health/"
  for _ in $(seq 1 30); do
    if curl -sf "$API_BASE_URL/health/" >/dev/null 2>&1; then echo "    backend is up"; break; fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then echo "ERROR: backend exited" >&2; exit 1; fi
    sleep 1
  done
fi

# --- Prepare the Flutter project ---------------------------------------------
echo "==> Preparing release build"
flutter pub get
if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  echo "    iOS project missing — running 'flutter create --platforms=ios .'"
  flutter create --platforms=ios .
fi
echo "    warming up Xcode…"
open -g ios/Runner.xcworkspace 2>/dev/null || true
sleep 8

# --- Build flags + optional auto-login ---------------------------------------
DEFINES=()
[[ -n "$API_BASE_URL" ]] && DEFINES+=(--dart-define=API_BASE_URL="$API_BASE_URL")
[[ -n "$GAMES_BASE_URL" ]] && DEFINES+=(--dart-define=GAMES_BASE_URL="$GAMES_BASE_URL")

LOGIN_NOTE="real sign-in (no dev auto-login)"
if [[ -n "$DEV_EMAIL" && -n "$DEV_PASSWORD" ]]; then
  DEFINES+=(--dart-define=DEV_EMAIL="$DEV_EMAIL" --dart-define=DEV_PASSWORD="$DEV_PASSWORD")
  LOGIN_NOTE="auto-login as $DEV_EMAIL"
  _base="${API_BASE_URL:-https://api.playstudy.app}"
  if curl -sf -X POST "$_base/api/v1/auth/email/" \
        -H 'Content-Type: application/json' \
        -d "{\"email\":\"$DEV_EMAIL\",\"password\":\"$DEV_PASSWORD\",\"name\":\"Dev\"}" \
        >/dev/null 2>&1; then
    echo "==> Seeded login on $_base"
  else
    echo "WARNING: couldn't reach $_base to seed the account." >&2
  fi
fi

cat <<BANNER

  ┌──────────────────────────────────────────────────────────┐
  │  PlayStudy — install (release build)                      │
  ├──────────────────────────────────────────────────────────┤
     Backend : ${API_BASE_URL:-https://api.playstudy.app (app default)}
     Games   : ${GAMES_BASE_URL:-https://playstudy.app (app default)}
     Device  : $TARGET_ID
     Login   : $LOGIN_NOTE
  └──────────────────────────────────────────────────────────┘
$( [[ -n "$WITH_BACKEND" ]] && echo "  Keep this terminal open — the app uses the backend on your Mac." )
  Tip: press 'q' to detach (release app stays installed on the phone).

BANNER

# The ${arr[@]+...} form is safe under `set -u` when DEFINES is empty (Bash 3.2).
flutter run --release -d "$TARGET_ID" ${DEFINES[@]+"${DEFINES[@]}"}
