#!/usr/bin/env bash
# Everything the app has said: captured stderr, unified log lines, crash reports.
# Usage: scripts/playtest/logs.sh [window, default 10m]
source "$(dirname "$0")/lib.sh"
window="${1:-10m}"

echo "== app stdout/stderr ($LOG_DIR/app-latest.log)"
if [ -f "$LOG_DIR/app-latest.log" ]; then tail -200 "$LOG_DIR/app-latest.log"; else echo "(none yet)"; fi

echo "== unified log, last $window (process ArcadeFighter)"
log show --last "$window" --style compact --predicate 'process == "ArcadeFighter"' 2>/dev/null \
  | tail -100 || echo "(log show unavailable)"

echo "== crash reports"
ls -t ~/Library/Logs/DiagnosticReports/ArcadeFighter* 2>/dev/null | head -5 || true
