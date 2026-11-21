#!/usr/bin/env bash
# Preflight: toolchain, repo freshness, and the two macOS permissions input + screenshots need.
# Usage: scripts/playtest/doctor.sh
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"
status=0

echo "== macOS $(sw_vers -productVersion) ($(uname -m))"
if xcodebuild -version >/dev/null 2>&1; then xcodebuild -version | head -1; else echo "MISSING Xcode (need 16.4+)"; status=1; fi
swift --version 2>&1 | head -1

echo "== repo"
git fetch -q origin main || echo "(fetch failed; freshness unknown)"
echo "branch=$(git rev-parse --abbrev-ref HEAD) head=$(git rev-parse --short HEAD) origin/main=$(git rev-parse --short origin/main)"
behind="$(git rev-list --count HEAD..origin/main)"
[ "$behind" = "0" ] || { echo "BEHIND origin/main by $behind commit(s)"; status=1; }
[ -z "$(git status --porcelain)" ] || echo "note: working tree has local changes"

echo "== permissions (granted to the terminal app running this, not to the game)"
ensure_tool
"$TOOL" permissions || status=1

exit $status
