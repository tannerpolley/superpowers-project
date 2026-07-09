#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 "$root/scripts/validate-workflow-graph.py"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf '%s\n' 'workflow_skills: {x: {purpose: x, validators: [x], gates: [{question_id: true, options: [true]}]}}' > "$tmp"
if python3 "$root/scripts/validate-workflow-graph.py" --path "$tmp" >/dev/null 2>&1; then
  echo "malformed workflow graph unexpectedly passed" >&2
  exit 1
fi
echo '{"ok":true,"phase":"workflow-graph","reason":"valid graph and malformed gate fixtures checked"}'
