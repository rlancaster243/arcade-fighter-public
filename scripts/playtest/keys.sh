#!/usr/bin/env bash
# Send input to the running game. Step syntax is documented at the top of PlaytestTool.swift.
# Examples:
#   scripts/playtest/keys.sh tap:return wait:400
#   scripts/playtest/keys.sh hold:d:600 tap:f seq:s,s+d,d+f:50
source "$(dirname "$0")/lib.sh"
ensure_tool
pid="$(require_game)"
PLAYTEST_SHOT_DIR="$SHOT_DIR" "$TOOL" keys "$pid" "$@" | tee -a "$LOG_DIR/inputs.log"
