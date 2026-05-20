#!/bin/bash
# SessionStart hook: provision the Flutter/Android dev environment for
# Claude Code on the web, then persist tool paths for the session.
set -euo pipefail

# Only run in the remote (web) environment; local machines manage their own SDKs.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

bash "$CLAUDE_PROJECT_DIR/scripts/dev-setup.sh"

# Persist tool paths so every command in this session can find flutter/dart/adb.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo 'export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"'
    echo 'export ANDROID_SDK_ROOT="/opt/android-sdk"'
    echo 'export PATH="/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH"'
  } >> "$CLAUDE_ENV_FILE"
fi
