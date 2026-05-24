#!/usr/bin/env bash
#
# run_ios.sh — single source of truth for running PlayStudy (Flutter) on iOS.
#
# What it does, in order:
#   1. Verifies the required tools are installed (flutter, xcode, cocoapods).
#   2. Generates the native iOS/Android platform folders if they don't exist yet
#      (this repo ships only lib/, so a plain `flutter run` would fail).
#   3. Fetches Dart packages.
#   4. Installs CocoaPods for the iOS runner.
#   5. Boots an iOS Simulator and launches the app on it.
#
# Usage:
#   ./run_ios.sh                 # build + run on an iOS Simulator (default)
#   ./run_ios.sh --device        # run on a connected physical iPhone
#   ./run_ios.sh --clean         # wipe build artifacts first, then run
#   ./run_ios.sh --setup-only    # do everything except launch the app
#
set -euo pipefail

# Always run from the directory this script lives in (the Flutter project root).
cd "$(dirname "${BASH_SOURCE[0]}")"

# ---- options -----------------------------------------------------------------
TARGET="simulator"   # simulator | device
DO_CLEAN=false
SETUP_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --device)     TARGET="device" ;;
    --clean)      DO_CLEAN=true ;;
    --setup-only) SETUP_ONLY=true ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#\s\?//' | head -n 20
      exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
  esac
done

say()  { printf "\n\033[1;34m▶ %s\033[0m\n" "$1"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$1"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$1" >&2; exit 1; }

# ---- 1. tool checks ----------------------------------------------------------
say "Checking required tools"
command -v flutter >/dev/null || die "Flutter not found. Install: https://docs.flutter.dev/get-started/install/macos"
command -v xcodebuild >/dev/null || die "Xcode not found. Install it from the App Store, then run: sudo xcodebuild -license accept"
command -v pod >/dev/null || die "CocoaPods not found. Install with: sudo gem install cocoapods (or: brew install cocoapods)"
ok "flutter, xcode, and cocoapods are available"

# ---- 2. clean (optional) -----------------------------------------------------
if $DO_CLEAN; then
  say "Cleaning build artifacts"
  flutter clean
  ok "clean done"
fi

# ---- 3. generate platform folders if missing ---------------------------------
# This repo only ships lib/ + pubspec.yaml. `flutter create .` scaffolds the
# native ios/ and android/ projects without overwriting your Dart code.
if [ ! -d "ios" ]; then
  say "No ios/ folder found — scaffolding native platforms"
  flutter create --platforms=ios,android .
  ok "platform folders created"
else
  ok "ios/ folder already present"
fi

# ---- 4. dart packages --------------------------------------------------------
say "Fetching Dart packages"
flutter pub get
ok "packages fetched"

# ---- 5. CocoaPods ------------------------------------------------------------
say "Installing CocoaPods (iOS native deps)"
( cd ios && pod install )
ok "pods installed"

if $SETUP_ONLY; then
  ok "Setup complete. Run './run_ios.sh' to launch the app."
  exit 0
fi

# ---- 6. launch ---------------------------------------------------------------
if [ "$TARGET" = "device" ]; then
  say "Launching on a connected iPhone"
  echo "Make sure your iPhone is plugged in, unlocked, and trusts this Mac."
  flutter run -d ios
else
  say "Booting an iOS Simulator"
  # Prefer the iPhone 15 Pro; fall back to any available iPhone simulator.
  SIM_UDID="$(xcrun simctl list devices available | grep -m1 'iPhone 15 Pro (' | grep -oE '[A-F0-9-]{36}')"
  if [ -z "$SIM_UDID" ]; then
    SIM_UDID="$(xcrun simctl list devices available | grep -m1 -oE 'iPhone[^(]*\(([A-F0-9-]+)\)' | grep -oE '[A-F0-9-]{36}')"
  fi
  [ -n "$SIM_UDID" ] || die "No iPhone simulator available. Open Xcode > Settings > Components to install one."

  # Open the Simulator app and wait until the device is fully booted, otherwise
  # `flutter run` checks too early and reports "No devices found".
  open -a Simulator
  xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
  say "Waiting for the simulator to finish booting"
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || true
  ok "simulator ready ($SIM_UDID)"

  say "Building and launching the app (first build takes a few minutes)"
  flutter run -d "$SIM_UDID"
fi
