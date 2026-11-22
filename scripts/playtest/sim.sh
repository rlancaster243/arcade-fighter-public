#!/usr/bin/env bash
# Headless check of the shipped roster through FightSim (no window, deterministic).
# Separates simulation bugs from rendering/input bugs before any GUI play.
# Usage: scripts/playtest/sim.sh [fighter ...]   (default: every shipped fighter vs greybox)
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT/FightCore"

fighters=("$@")
if [ ${#fighters[@]} -eq 0 ]; then
  fighters=()
  for d in "$REPO_ROOT"/Content/Fighters/*/; do fighters+=("$(basename "$d")"); done
fi

swift build -c release --product FightSim >/dev/null
for f in "${fighters[@]}"; do
  out="$LOG_DIR/fightsim-$f-vs-greybox.json"
  if swift run -c release --skip-build FightSim --roster --p1-fighter "$f" --p2-fighter greybox \
       --seed-start 1 --seed-end 5 --quiet --json-out "$out" 2>"$LOG_DIR/fightsim-$f.err"; then
    echo "ok   $f vs greybox -> $out"
  else
    echo "FAIL $f vs greybox:"; cat "$LOG_DIR/fightsim-$f.err"
  fi
done
