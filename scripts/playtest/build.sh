#!/usr/bin/env bash
# Run core tests, build the app, ad-hoc sign it with the shipped entitlements, compile the helper.
# Usage: scripts/playtest/build.sh [--skip-tests]
#        PLAYTEST_CONFIG=Release scripts/playtest/build.sh   (default Debug)
source "$(dirname "$0")/lib.sh"

skip_tests=false
[ "${1:-}" = "--skip-tests" ] && skip_tests=true

ts="$(timestamp)"
cd "$REPO_ROOT"
echo "== repo: $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
echo "== toolchain"
xcodebuild -version | head -1
swift --version 2>&1 | head -1

if ! $skip_tests; then
  echo "== swift test (FightCore) -> $LOG_DIR/swift-test-$ts.log"
  if ! (cd FightCore && swift test --parallel) >"$LOG_DIR/swift-test-$ts.log" 2>&1; then
    echo "FAIL: swift test. Last 40 lines:"
    tail -40 "$LOG_DIR/swift-test-$ts.log"
    exit 1
  fi
  tail -3 "$LOG_DIR/swift-test-$ts.log"
fi

echo "== xcodebuild $CONFIG -> $LOG_DIR/xcodebuild-$ts.log"
if ! xcodebuild build \
    -project ArcadeFighter.xcodeproj \
    -scheme ArcadeFighter \
    -configuration "$CONFIG" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO >"$LOG_DIR/xcodebuild-$ts.log" 2>&1; then
  echo "FAIL: xcodebuild. Errors:"
  grep -E "error:|BUILD FAILED" "$LOG_DIR/xcodebuild-$ts.log" | head -40
  exit 1
fi

echo "== ad-hoc sign with App/ArcadeFighter.entitlements (sandbox on, like CI)"
codesign --force --deep --sign - --entitlements App/ArcadeFighter.entitlements "$APP_PATH"
codesign --verify --strict "$APP_PATH"

echo "== bundled content check"
for f in Content/Fighters/greybox/greybox.contentbundle/fighter.json Content/Audio/manifest.json; do
  if [ -f "$APP_PATH/Contents/Resources/$f" ]; then echo "ok  $f"; else echo "MISSING $f"; fi
done

ensure_tool
echo "== built: $APP_PATH"
