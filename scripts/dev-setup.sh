#!/bin/bash
# Provision a full Flutter + Android dev environment for GrabBit.
# Idempotent and non-interactive; safe to re-run. Used by the SessionStart hook
# (Claude Code on the web) and runnable by hand for local setup.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/opt/flutter}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
FLUTTER_CHANNEL="stable"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
ANDROID_PLATFORM="platforms;android-35"
ANDROID_BUILD_TOOLS="build-tools;35.0.0"

log() { echo "[dev-setup] $*"; }

# 1. Flutter SDK (required) -------------------------------------------------
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  log "installing Flutter ($FLUTTER_CHANNEL) into $FLUTTER_DIR"
  git clone --depth 1 --branch "$FLUTTER_CHANNEL" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  log "Flutter already present at $FLUTTER_DIR"
fi
git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true
export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"
flutter --version

# 2. Android SDK (best-effort; only needed to build APKs locally) -----------
if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "installing Android SDK command-line tools into $ANDROID_SDK_ROOT"
  if mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools" \
    && tmp="$(mktemp -d)" \
    && curl -fsSL -o "$tmp/clt.zip" "$CMDLINE_TOOLS_URL" \
    && unzip -q "$tmp/clt.zip" -d "$ANDROID_SDK_ROOT/cmdline-tools" \
    && mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" \
          "$ANDROID_SDK_ROOT/cmdline-tools/latest"; then
    SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
    yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
    "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" \
      "platform-tools" "$ANDROID_PLATFORM" "$ANDROID_BUILD_TOOLS" >/dev/null \
      || log "WARN: Android SDK package install failed (APK builds may be unavailable)"
  else
    log "WARN: Android SDK download/extract failed (APK builds may be unavailable)"
  fi
else
  log "Android SDK already present at $ANDROID_SDK_ROOT"
fi
export ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# 3. Project dependencies ---------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$PROJECT_DIR"
log "running flutter pub get"
flutter pub get

log "done."
