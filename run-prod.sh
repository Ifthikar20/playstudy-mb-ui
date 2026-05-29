#!/usr/bin/env bash
# Production-style run: builds a RELEASE build and installs it on your iPhone,
# pointed at the production backend + games, with NO dev auto-login (you sign in
# normally). Use ./run-dev.sh for local development instead.
#
#   ./run-prod.sh                         # install on the default device, prod URLs
#   DEVICE=auto ./run-prod.sh             # auto-detect the connected iPhone
#   API_BASE_URL=https://staging.api ... ./run-prod.sh   # point at staging
set -euo pipefail
cd "$(dirname "$0")"

# Default to the physical iPhone. Override with DEVICE=<id|name|auto>.
DEVICE="${DEVICE-AliIphone2024}"

# Production URLs come from the app's built-in defaults (AppConfig) unless you
# override them here. Leave unset to ship the real production endpoints.
API_BASE_URL="${API_BASE_URL:-}"
GAMES_BASE_URL="${GAMES_BASE_URL:-}"

# --- Resolve the target device (must be a real device for an install) --------
TARGET_ID=""
if [[ "$DEVICE" == "auto" ]]; then
  TARGET_ID="$(flutter devices --machine 2>/dev/null | python3 -c "import sys,json
try: ds=json.load(sys.stdin)
except Exception: ds=[]
ios=[d for d in ds if 'ios' in (d.get('targetPlatform') or '') and not d.get('emulator')]
print(ios[0]['id'] if ios else '')" 2>/dev/null || true)"
  if [[ -z "$TARGET_ID" ]]; then
    echo "ERROR: no physical iOS device found. Unlock your iPhone, keep it on the" >&2
    echo "same Wi-Fi/cable, and make sure it's paired in Xcode." >&2
    exit 1
  fi
else
  TARGET_ID="$DEVICE"
fi

# --- Prepare the Flutter project ---------------------------------------------
echo "==> Preparing release build"
flutter pub get
if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  echo "    iOS project missing — running 'flutter create --platforms=ios .'"
  flutter create --platforms=ios .
fi

# Pre-warm Xcode so a wireless install/attach doesn't time out.
echo "    warming up Xcode…"
open -g ios/Runner.xcworkspace 2>/dev/null || true
sleep 8

# --- Build flags --------------------------------------------------------------
DEFINES=()
[[ -n "$API_BASE_URL" ]] && DEFINES+=(--dart-define=API_BASE_URL="$API_BASE_URL")
[[ -n "$GAMES_BASE_URL" ]] && DEFINES+=(--dart-define=GAMES_BASE_URL="$GAMES_BASE_URL")

cat <<BANNER

  ┌──────────────────────────────────────────────────────────┐
  │  PlayStudy — PRODUCTION install (release build)           │
  ├──────────────────────────────────────────────────────────┤
     Backend : ${API_BASE_URL:-https://api.playstudy.app (app default)}
     Games   : ${GAMES_BASE_URL:-https://playstudy.app (app default)}
     Device  : $TARGET_ID
     Login   : real sign-in (no dev auto-login)
  └──────────────────────────────────────────────────────────┘
  Tip: once it launches, press 'q' to detach — the app stays
  installed on the iPhone and runs on its own (release build).

BANNER

# --noreload/hot-reload don't apply in release; this builds, signs, installs,
# and launches the release app on the device.
flutter run --release -d "$TARGET_ID" "${DEFINES[@]}"
