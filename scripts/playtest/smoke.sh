#!/usr/bin/env bash
# Scripted end-to-end pass: title -> menus -> versus match -> P1/P2 actions -> pause/resume.
# Leaves the game running for exploratory play. Screenshots land in build/playtest/shots/.
# Usage: scripts/playtest/smoke.sh
export PLAYTEST_SHOT_DIR="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/build/playtest/shots/smoke-$(date +%Y%m%d-%H%M%S)"
source "$(dirname "$0")/lib.sh"
here="$(dirname "$0")"

"$here/launch.sh"
pid="$(require_game)"
k() { "$here/keys.sh" "$@"; }

echo "== menus"
k shot:01-title \
  tap:return wait:500 shot:02-main-menu \
  tap:down wait:250 shot:03-main-menu-versus-highlighted \
  tap:return wait:500 shot:04-versus-setup \
  tap:return wait:500 shot:05-select-p1 \
  tap:right wait:300 shot:06-select-p1-after-right \
  tap:return wait:500 shot:07-select-p2 \
  tap:return wait:2000 shot:08-match-start

echo "== P1 (WASD + F/G/H/J), starts on the left facing right"
k hold:d:500 shot:09-p1-walked-forward \
  tap:f wait:80 shot:10-p1-light-punch wait:400 \
  tap:g wait:120 shot:11-p1-heavy-punch wait:500 \
  seq:s,s+d,d+f:50 wait:150 shot:12-p1-qcf-lp wait:600 \
  press:s wait:250 shot:13-p1-crouch release:s wait:200 \
  tap:w wait:250 shot:14-p1-jump-apex wait:800

echo "== P2 (arrows + numpad 4/5/1/2), starts on the right facing left"
k hold:left:500 shot:15-p2-walked-forward \
  tap:kp4 wait:80 shot:16-p2-light-punch wait:500

echo "== pause / resume"
k tap:p wait:500 shot:17-paused tap:p wait:500 shot:18-resumed

echo "== logs"
"$here/logs.sh" 5m | tee "$LOG_DIR/smoke-logs.txt"

kill -0 "$pid" 2>/dev/null && echo "== game still running (pid $pid)" || echo "== GAME EXITED during smoke run"
echo "== screenshots (in order):"
ls -1 "$SHOT_DIR" | sed "s|^|$SHOT_DIR/|"
