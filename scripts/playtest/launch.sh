#!/usr/bin/env bash
# Launch the built app with stdout/stderr captured, wait for its window, bring it to the front.
# Usage: scripts/playtest/launch.sh
source "$(dirname "$0")/lib.sh"
ensure_tool

[ -x "$APP_BIN" ] || { echo "playtest: no build at $APP_PATH; run scripts/playtest/build.sh" >&2; exit 1; }

if pid="$(game_pid)"; then
  echo "== stopping previous instance (pid $pid)"
  kill "$pid" 2>/dev/null || true
  sleep 1
fi

ts="$(timestamp)"
log="$LOG_DIR/app-$ts.log"
# Run the executable directly (not `open`) so the app's stderr notices land in the log.
# nohup + disown: the game must outlive this script and the shell that ran it.
nohup "$APP_BIN" >"$log" 2>&1 </dev/null &
pid=$!
disown "$pid" 2>/dev/null || true
echo "$pid" >"$PID_FILE"
ln -sf "app-$ts.log" "$LOG_DIR/app-latest.log"

for _ in $(seq 1 60); do
  if "$TOOL" window-id "$pid" >/dev/null 2>&1; then break; fi
  kill -0 "$pid" 2>/dev/null || { echo "playtest: app exited during launch. Log:"; cat "$log"; exit 1; }
  sleep 0.25
done
"$TOOL" window-id "$pid" >/dev/null || { echo "playtest: no window after 15s"; exit 1; }
"$TOOL" activate "$pid"
sleep 0.5
echo "pid=$pid"
echo "log=$log"
