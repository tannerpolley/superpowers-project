from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _plan() -> str:
    fields = {
        "Intent": "validate the registry",
        "Current Behavior": "dispatch is explicit",
        "Expected Outcome": "accepted fixtures pass",
        "Target Output": "JSON ok true",
        "Owner": "maintainer",
        "Interface": "shell launcher",
        "Cutover": "retire heuristic path",
        "Replaced Path": "scripts/lib/old-dispatch.py",
        "Evidence": "target-perspective review",
        "Acceptance Proof": "operator-visible behavior",
        "Stop Criteria": "any failed validator",
        "Avoid": "silent defaults",
        "Risk": "schema drift",
    }
    boundaries = {
        "Files To Create": "fixture files",
        "Files To Modify": "validator fixtures",
        "Files To Avoid": "legacy shell wrappers",
        "Source Of Truth": "command registry",
        "Read Path": "plan markdown",
        "Write Path": "JSON result",
        "Integration Points": "four launchers",
        "Migration Or Cutover": "retire old path",
        "Replaced Path Handling": "remove obsolete dispatch",
        "Acceptance Proof Gate": "operator-visible behavior",
    }
    text = ["# Plan", "", "## Task 1: Example", "**Use Cases:**", "- verify acceptance evidence and cutover/retire", "**Files:**", "- fixture"]
    text += ["", "## Outcome Proof"] + [f"**{k}:** {v}" for k, v in fields.items()]
    text += ["", "## Implementation Boundaries"] + [f"**{k}:** {v}" for k, v in boundaries.items()]
    text += ["", "## Decision Ledger", "| decision | source | answer | impact | deferred? | risk owner |", "| --- | --- | --- | --- | --- | --- |", "| registry | Task 1 | explicit | fail closed | no | maintainer |"]
    return "\n".join(text) + "\n"


def _workflow() -> dict[str, object]:
    return {
        "question_id": "project_workflow_mode", "source": "request_user_input", "selected_mode": "manual",
        "repo_root": ".", "plugin_manifest_version": "1", "plugin_contract_hash": "fixture-hash", "started_at": "2026-01-01T00:00:00Z",
        "autonomy_scope": "ask-every-material-decision", "mutation_scope": ["current-repo"], "candidate_scope": ["task-1"],
        "route_policy": "manual", "proof_policy": "target-perspective", "stop_conditions": ["failed-validation"],
        "downstream_ledger_paths": [".superpowers/sdd/mode-ledger.json"],
    }


def main(kind: str) -> int:
    plugin_root = Path(__file__).resolve().parents[2]
    root = Path(tempfile.mkdtemp(prefix="sp-validator-", dir=plugin_root / ".superpowers/sdd"))
    try:
        plan = root / "docs/superpowers/plans/sample.md"
        plan.parent.mkdir(parents=True)
        script = {"task": "scripts/test-plan-task-use-cases.sh", "outcome": "scripts/test-plan-outcome-proof.sh", "decision": "scripts/test-decision-ledger.sh", "workflow": "scripts/test-workflow-mode-ledger.sh"}[kind]
        if kind == "workflow":
            ledger = root / "docs/superpowers/runs/mode-ledger.json"
            ledger.parent.mkdir(parents=True)
            ledger.write_text(json.dumps(_workflow()))
            args = ["-ModeLedgerPath", "docs/superpowers/runs/mode-ledger.json", "-RepoRoot", str(root)]
            invalid = {**_workflow(), "selected_mode": "bogus"}
            cases = [(None, 0), (invalid, 1)]
        else:
            good = _plan()
            bad = "# Plan\n\n## Task 1: Example\n**Files:**\n- x\n"
            if kind == "decision":
                args = ["-Path", "docs/superpowers/plans/sample.md", "-Kind", "plan", "-RepoRoot", str(root)]
            else:
                args = ["-PlanPath", "docs/superpowers/plans/sample.md", "-RepoRoot", str(root)]
            cases = [(good, 0), (bad, 1)]
        for content, expected in cases:
            if kind == "workflow":
                ledger.write_text(json.dumps(_workflow() if content is None else content))
            else:
                plan.write_text(content)
            result = subprocess.run(["bash", str(plugin_root / script), *args], cwd=plugin_root, text=True, capture_output=True)
            payload = json.loads(result.stdout)
            if result.returncode != expected or payload.get("ok") is not (expected == 0):
                return 1
        return 0
    finally:
        shutil.rmtree(root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
