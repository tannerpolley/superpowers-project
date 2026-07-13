#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "-DispatchProbe" || "${1:-}" == "--dispatch-probe" ]]; then
  exec "$plugin_root/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
fi
export PYTHONPATH="$plugin_root${PYTHONPATH:+:$PYTHONPATH}"
python3 - <<'PY' "$plugin_root"
import sys
import tempfile
from pathlib import Path
from scripts.lib.workflow_state import WorkflowStateError, append_event, replay_events

with tempfile.TemporaryDirectory(prefix="workflow-runtime-") as tmp:
    root = Path(tmp) / "run"
    append_event(root, {"type": "run_started", "run_id": "dummy-auto"})
    append_event(root, {"type": "candidate_selected", "candidate": "one"})
    try:
        append_event(root, {"type": "candidate_selected", "candidate": "two"})
    except WorkflowStateError:
        pass
    else:
        raise SystemExit("second candidate was not blocked")
    append_event(root, {"type": "candidate_accepted", "candidate": "one"})
    append_event(root, {"type": "verifier_passed", "candidate": "one"})
    append_event(root, {
        "type": "budget_rechecked",
        "candidate": "one",
        "evidence": {
            "budget_path": "budget.json",
            "budget_hash": "a" * 64,
            "health_path": "health.json",
            "health_hash": "b" * 64,
        },
    })
    append_event(root, {"type": "continuation_granted", "candidate": "one"})
    append_event(root, {"type": "candidate_selected", "candidate": "two"})
    projection = replay_events(root / "events.jsonl")
    assert projection.selected_candidate == "two"
    assert projection.events == 7
print("workflow runtime fixture passed")
PY
