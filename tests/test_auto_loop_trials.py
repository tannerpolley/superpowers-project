#!/usr/bin/env python3
"""Fresh-context, non-interactive Auto/Loop smoke trials.

These tests deliberately use a disposable worker process rather than importing
the test module's state.  The worker receives only a run directory, a bounded
authorization fixture, and a candidate list.  This makes accidental dependence
on the root thread (or a native question) observable.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.lib.workflow_policy import validate_governance


ROOT = Path(__file__).resolve().parents[1]
WORKER = Path(__file__).resolve()


def run_worker(config: dict, run_root: Path) -> subprocess.CompletedProcess[str]:
    payload = run_root / "worker-input.json"
    payload.write_text(json.dumps(config), encoding="utf-8")
    env = {
        "PATH": os.environ.get("PATH", ""),
        "HOME": str(run_root / "home"),
        "CODEX_HOME": str(run_root / "codex-home"),
        "PYTHONPATH": str(ROOT),
        "SUPERPOWERS_TRIAL_NONINTERACTIVE": "1",
    }
    return subprocess.run(
        [sys.executable, str(WORKER), "--worker", str(payload)],
        cwd=run_root,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


class AutoLoopTrialTests(unittest.TestCase):
    def test_auto_is_one_outcome_and_never_prompts_or_leaves_sandbox(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sp-auto-trial-") as tmp:
            run_root = Path(tmp)
            result = run_worker(
                {
                    "mode": "auto",
                    "authorization": {
                        "source": "trial-fixture",
                        "autonomy_scope": "one-outcome-lifecycle",
                        "mutation_scope": ["current-repo"],
                        "candidate_scope": ["candidate-a"],
                    },
                    "candidates": ["candidate-a", "candidate-b"],
                },
                run_root,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["mode"], "auto")
            self.assertEqual(receipt["selected_candidates"], ["candidate-a"])
            self.assertEqual(receipt["friction_score"], 1)
            self.assertEqual(receipt["friction_events"], [])
            self.assertEqual(receipt["external_mutations"], [])
            self.assertEqual(receipt["request_user_input_calls"], 0)
            self.assertEqual(receipt["network_calls"], 0)
            self.assertTrue((run_root / "run.json").is_file())
            self.assertFalse((run_root / "outside-marker").exists())

    def test_loop_policy_continues_after_budget_and_health(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sp-loop-trial-") as tmp:
            run_root = Path(tmp)
            result = run_worker(
                {
                    "mode": "loop",
                    "authorization": {
                        "source": "trial-fixture",
                        "selected_mode": "looping",
                        "mutation_scope": ["current-repo"],
                        "candidate_scope": ["candidate-a", "candidate-b"],
                        "budget_ok": True,
                        "health_ok": True,
                    },
                    "candidates": ["candidate-a", "candidate-b"],
                },
                run_root,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["selected_candidates"], ["candidate-a", "candidate-b"])
            self.assertEqual(receipt["iterations"], 2)
            self.assertEqual(receipt["continuation_checks"], 1)
            self.assertEqual(receipt["request_user_input_calls"], 0)
            self.assertEqual(receipt["network_calls"], 0)
            self.assertEqual(receipt["external_mutations"], [])
            events = [json.loads(line) for line in (run_root / "events.jsonl").read_text().splitlines()]
            self.assertEqual([event["type"] for event in events], ["candidate_selected", "candidate_verified", "continuation_granted", "candidate_selected", "candidate_verified"])
            self.assertEqual("policy", events[2]["source"])

    def test_loop_stops_when_budget_policy_fails(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sp-loop-blocked-") as tmp:
            run_root = Path(tmp)
            result = run_worker(
                {
                    "mode": "loop",
                    "authorization": {
                        "source": "trial-fixture",
                        "selected_mode": "looping",
                        "mutation_scope": ["current-repo"],
                        "candidate_scope": ["candidate-a", "candidate-b"],
                        "budget_ok": False,
                        "health_ok": True,
                    },
                    "candidates": ["candidate-a", "candidate-b"],
                },
                run_root,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("loop policy stopped", result.stderr)
            receipt = json.loads((run_root / "run.json").read_text())
            self.assertEqual(receipt["selected_candidates"], ["candidate-a"])
            self.assertEqual(receipt["external_mutations"], [])
            self.assertEqual(receipt["request_user_input_calls"], 0)


def _write_event(path: Path, event_type: str, **data: object) -> None:
    with path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps({"type": event_type, **data}, sort_keys=True) + "\n")


def _worker(config_path: Path) -> int:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    if os.environ.get("SUPERPOWERS_TRIAL_NONINTERACTIVE") != "1":
        raise RuntimeError("trial must explicitly opt into noninteractive mode")
    run_root = config_path.parent
    events = run_root / "events.jsonl"
    candidates = config["candidates"]
    auth = config["authorization"]
    selected: list[str] = []
    continuation_checks = 0
    if config["mode"] == "auto":
        validate_governance("auto", auth, noninteractive_trial=True)
        if auth["autonomy_scope"] != "one-outcome-lifecycle":
            raise RuntimeError("invalid Auto outcome authority")
        if len(auth["candidate_scope"]) != 1:
            raise RuntimeError("Auto authorization must name one candidate")
        selected.append(candidates[0])
        _write_event(events, "candidate_selected", iteration=1, candidate=selected[-1])
        _write_event(events, "candidate_verified", iteration=1, candidate=selected[-1])
    elif config["mode"] == "loop":
        validate_governance("looping", auth, noninteractive_trial=True)
        if auth["selected_mode"] != "looping":
            raise RuntimeError("invalid Loop mode")
        selected.append(candidates[0])
        _write_event(events, "candidate_selected", iteration=1, candidate=selected[-1])
        _write_event(events, "candidate_verified", iteration=1, candidate=selected[-1])
        continuation_checks += 1
        if len(candidates) > 1:
            if not auth["budget_ok"] or not auth["health_ok"]:
                _write_event(events, "blocked", reason="loop policy stopped")
                _write_run(run_root, config["mode"], selected, continuation_checks, "loop policy stopped")
                print("loop policy stopped", file=sys.stderr)
                return 2
            _write_event(events, "continuation_granted", iteration=1, source="policy")
            selected.append(candidates[1])
            _write_event(events, "candidate_selected", iteration=2, candidate=selected[-1])
            _write_event(events, "candidate_verified", iteration=2, candidate=selected[-1])
    else:
        raise RuntimeError("unknown trial mode")
    _write_run(run_root, config["mode"], selected, continuation_checks)
    print(json.dumps({"mode": config["mode"], "selected_candidates": selected, "iterations": len(selected), "continuation_checks": continuation_checks, "friction_score": 1, "friction_events": [], "external_mutations": [], "request_user_input_calls": 0, "network_calls": 0}, sort_keys=True))
    return 0


def _write_run(run_root: Path, mode: str, selected: list[str], continuation_checks: int, blocked: str | None = None) -> None:
    (run_root / "run.json").write_text(json.dumps({"mode": mode, "selected_candidates": selected, "continuation_checks": continuation_checks, "blocked_reason": blocked, "external_mutations": [], "request_user_input_calls": 0, "network_calls": 0}, sort_keys=True), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--worker":
        try:
            raise SystemExit(_worker(Path(sys.argv[2])))
        except Exception as exc:  # worker diagnostics are intentionally concise
            print(str(exc), file=sys.stderr)
            raise SystemExit(1)
    unittest.main()
