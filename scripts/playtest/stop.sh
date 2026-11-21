#!/usr/bin/env bash
# Quit the game this kit launched.
source "$(dirname "$0")/lib.sh"
if pid="$(game_pid)"; then
  kill "$pid" && echo "stopped pid $pid"
else
  echo "not running"
fi
rm -f "$PID_FILE"
