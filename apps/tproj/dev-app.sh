#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/dist/tproj.app"
DEBUG_BIN="$SCRIPT_DIR/.build/arm64-apple-macosx/debug/tproj"
MODE="debug"
TPROJ_GUI_PIDFILE="${TMPDIR:-/tmp}/tproj-gui.pid"

if [[ "${1:-}" == "--release" ]]; then
  MODE="release"
fi

# --- Build ---
if [[ "$MODE" == "debug" ]]; then
  echo "==> Build app (debug)"
  pushd "$SCRIPT_DIR" >/dev/null
  swift build
  popd >/dev/null
else
  echo "==> Build app (release)"
  "$SCRIPT_DIR/build-app.sh"
fi

# --- Stop ALL previous GUI processes (PID file + pattern) ---
echo "==> Stop previous GUI processes"
if [[ -f "$TPROJ_GUI_PIDFILE" ]]; then
  kill "$(<"$TPROJ_GUI_PIDFILE")" 2>/dev/null || true
  rm -f "$TPROJ_GUI_PIDFILE"
fi
pkill -f 'apps/tproj/dist/tproj.app/Contents/MacOS/tproj|\.build/.*/debug/tproj|tproj-gui' 2>/dev/null || true
sleep 0.3

# --- Launch ---
if [[ "$MODE" == "debug" ]]; then
  echo "==> Launch app (debug)"
  "$DEBUG_BIN" &
  echo "$!" > "$TPROJ_GUI_PIDFILE"
  sleep 1
  local_pid="$(<"$TPROJ_GUI_PIDFILE")"
  if ! kill -0 "$local_pid" 2>/dev/null; then
    echo "debug process (pid $local_pid) not detected; check build output" >&2
    exit 1
  fi
  echo "Done: $DEBUG_BIN (pid $local_pid)"
else
  echo "==> Launch app (release)"
  "$APP_BUNDLE/Contents/MacOS/tproj" &
  echo "$!" > "$TPROJ_GUI_PIDFILE"
  sleep 1
  local_pid="$(<"$TPROJ_GUI_PIDFILE")"
  if ! kill -0 "$local_pid" 2>/dev/null; then
    echo "app process (pid $local_pid) not detected; check build output" >&2
    exit 1
  fi
  echo "Done: $APP_BUNDLE (pid $local_pid)"
fi
