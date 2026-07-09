#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
receipt="$root/.superpowers/sdd/.release-proof-receipt.json"; trap 'rm -f "$receipt"' EXIT
if "$root/scripts/prepare-release.sh" -OutputPath "$receipt" "$@" >/dev/null 2>&1; then
  echo "release proof unexpectedly passed without a clean worktree/versioned receipt" >&2
  exit 1
fi
test -s "$receipt"
python3 - "$receipt" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("ok") is False or d.get("publish_ready") is False
PY
printf '%s\n' '{"ok":true,"phase":"release-proof","reason":"invalid release state and missing clean receipt are rejected"}'
