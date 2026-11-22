#!/usr/bin/env bash
# Screenshot the game window (not the whole screen). Prints the PNG path.
# Usage: scripts/playtest/shot.sh <label>
source "$(dirname "$0")/lib.sh"
ensure_tool
pid="$(require_game)"
label="${1:-shot}"
out="$SHOT_DIR/$(timestamp)-$label.png"
wid="$("$TOOL" window-id "$pid")"
screencapture -x -o -l "$wid" "$out"
echo "$out"
