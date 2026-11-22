# Shared paths and helpers for scripts/playtest/*.sh. Source it; don't run it.
# shellcheck shell=bash

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "playtest: macOS only (the app is SpriteKit/AppKit)." >&2
  exit 1
fi

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
PLAYTEST_DIR="$REPO_ROOT/build/playtest"
LOG_DIR="$PLAYTEST_DIR/logs"
SHOT_DIR="${PLAYTEST_SHOT_DIR:-$PLAYTEST_DIR/shots}"
BIN_DIR="$PLAYTEST_DIR/bin"
PID_FILE="$PLAYTEST_DIR/app.pid"
CONFIG="${PLAYTEST_CONFIG:-Debug}"
DERIVED="$REPO_ROOT/build/DerivedData"
APP_PATH="$DERIVED/Build/Products/$CONFIG/ArcadeFighter.app"
APP_BIN="$APP_PATH/Contents/MacOS/ArcadeFighter"
TOOL_SRC="$REPO_ROOT/scripts/playtest/PlaytestTool.swift"
TOOL="$BIN_DIR/playtest"

mkdir -p "$LOG_DIR" "$SHOT_DIR" "$BIN_DIR"

timestamp() { date +%Y%m%d-%H%M%S; }

# Compile the Swift helper when missing or older than its source.
ensure_tool() {
  if [ ! -x "$TOOL" ] || [ "$TOOL_SRC" -nt "$TOOL" ]; then
    echo "playtest: compiling helper tool..." >&2
    swiftc -O -swift-version 5 -o "$TOOL" "$TOOL_SRC"
  fi
}

# Pid of the game this kit launched, if it is still running.
game_pid() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE")"
  kill -0 "$pid" 2>/dev/null || return 1
  echo "$pid"
}

require_game() {
  game_pid || { echo "playtest: game is not running; run scripts/playtest/launch.sh" >&2; exit 1; }
}
