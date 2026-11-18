#!/usr/bin/env bash
# T-ADAPT-SCRIPT: macOS adapter files must not hardcode key codes; use AppLogic symbols.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
APP_INPUT="${ROOT}/App/Input"

if [[ ! -d "$APP_INPUT" ]]; then
  echo "missing App/Input at $APP_INPUT" >&2
  exit 1
fi

# Fail if any Swift file under App/Input uses a suspicious bare hex key literal.
if rg -n 'keyCode.*0x[0-9A-Fa-f]{2}' "$APP_INPUT" --glob '*.swift'; then
  echo "T-ADAPT-SCRIPT: hardcoded keyCode hex literals found in App/Input" >&2
  exit 1
fi

# Adapters must reference MacVirtualKeyCode from AppLogic.
if ! rg -q 'MacVirtualKeyCode' "$APP_INPUT" --glob '*.swift'; then
  echo "T-ADAPT-SCRIPT: expected MacVirtualKeyCode usage in App/Input" >&2
  exit 1
fi

# Keyboard path must mention isARepeat (ignore auto-repeat).
if ! rg -q 'isARepeat' "$APP_INPUT" --glob '*Keyboard*.swift'; then
  echo "T-ADAPT-SCRIPT: keyboard adapter must filter isARepeat" >&2
  exit 1
fi

# Gamepad path must reference 0.5 deadzone (literal or AppLogic default).
if ! rg -q '0\\.5|defaultDeadzone' "$APP_INPUT" --glob '*GameController*.swift'; then
  echo "T-ADAPT-SCRIPT: gamepad adapter must use 0.5 deadzone" >&2
  exit 1
fi

echo "T-ADAPT-SCRIPT: OK"