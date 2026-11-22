#!/usr/bin/env bash
# Re-record FightCore integration goldens after an INTENDED simulation change, then rerun tests.
# Review the diff: every changed scenario should be explained by the change you made.
# Usage: scripts/record-expected-hashes.sh
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
catalog="$root/FightCore/Tests/FightCoreTests/Contracts/expected-hashes.json"
tmp="$(mktemp -t expected-hashes)"
trap 'rm -f "$tmp"' EXIT

cd "$root/FightCore"
RECORD_EXPECTED_HASHES="$tmp" swift test --filter ExpectedHashesRecorder >/dev/null
python3 -I - "$catalog" "$tmp" <<'PY'
import json, sys
catalog_path, recorded_path = sys.argv[1], sys.argv[2]
catalog = json.load(open(catalog_path))
recorded = json.load(open(recorded_path))
changed = []
for s in catalog["scenarios"]:
    new = recorded[s["id"]]
    if new != s["tickHashes"]:
        changed.append(s["id"])
        s["tickHashes"] = new
with open(catalog_path, "w") as f:
    f.write(json.dumps(catalog, indent=2) + "\n")
print("re-recorded:", ", ".join(changed) if changed else "(no changes)")
PY
swift test --parallel >/dev/null && echo "swift test: PASS"
