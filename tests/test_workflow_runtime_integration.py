from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "workflow-run.sh"


class WorkflowRuntimeIntegrationTests(unittest.TestCase):
    def invoke(self, project: Path, run_root: Path, authorization: Path, action: str, *extra: str):
        return subprocess.run(
            [
                "bash",
                str(SCRIPT),
                "-RepoRoot",
                str(project),
                "-RunRoot",
                str(run_root),
                "-AuthorizationPath",
                str(authorization),
                "-Action",
                action,
                *extra,
            ],
            cwd="/tmp",
            text=True,
            capture_output=True,
        )

    def fixture(self, root: Path, mode: str, *, source: str = "trial-fixture") -> tuple[Path, Path, Path]:
        project = root / "project"
        project.mkdir()
        run_root = project / ".superpowers" / "runs" / "trial"
        authorization = project / "authorization.json"
        authorization.write_text(
            json.dumps(
                {
                    "source": source,
                    "mode": mode,
                    "repo_root": str(project.resolve()),
                    "candidate_scope": ["one"] if mode == "auto" else ["one", "two"],
                }
            )
        )
        return project, run_root, authorization

    def loop_evidence(self, project: Path, candidate: str, *, budget_ok: bool = True, health_ok: bool = True) -> tuple[Path, Path]:
        budget = project / "budget.json"
        budget.write_text(json.dumps({
            "candidate_id": candidate,
            "candidates_completed": 1 if budget_ok else 2,
            "max_candidates": 2,
            "current_phase_attempts": 0,
            "max_attempts_per_phase": 2,
            "repeated_same_failure_count": 0,
            "max_repeated_same_failure": 2,
            "changed_files": 1,
            "max_changed_files": 10,
            "github_mutations": 0,
            "max_github_mutations": 2,
            "validator_reruns": 1,
            "max_validator_reruns": 3,
            "unreviewed_diff_lines": 0,
            "max_unreviewed_diff_lines": 100,
        }), encoding="utf-8")
        health = project / "health.json"
        health.write_text(json.dumps({
            "candidate_id": candidate,
            "verifier_type": "independent",
            "independent": True,
            "proof": [{"command": "focused tests", "ok": health_ok, "artifact": "test-output"}],
        }), encoding="utf-8")
        return budget, health

    def assert_ok(self, result: subprocess.CompletedProcess[str]) -> dict:
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"])
        return payload

    def test_auto_records_one_outcome_and_completes_after_proof(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-1"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "mutate", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "accept", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "verify", "-Candidate", "one"))
            completed = self.assert_ok(self.invoke(project, run_root, auth, "complete", "-Claim", "outcome"))
            self.assertEqual("completed", completed["projection"]["status"])
            rejected = self.invoke(project, run_root, auth, "select", "-Candidate", "two")
            self.assertNotEqual(0, rejected.returncode)

    def test_auto_starts_from_the_real_native_selection_ledger(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto", source="request_user_input")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-native"))

    def test_loop_requires_all_iteration_gates_before_second_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "looping")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "loop-1"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "one"))
            rejected = self.invoke(project, run_root, auth, "select", "-Candidate", "two")
            self.assertNotEqual(0, rejected.returncode)
            rejected = self.invoke(project, run_root, auth, "grant-continuation", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)
            self.assert_ok(self.invoke(project, run_root, auth, "accept", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "verify", "-Candidate", "one"))
            rejected = self.invoke(project, run_root, auth, "recheck-budget", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)
            budget, health = self.loop_evidence(project, "one")
            self.assert_ok(self.invoke(project, run_root, auth, "recheck-budget", "-Candidate", "one", "-BudgetEvidencePath", str(budget), "-HealthEvidencePath", str(health)))
            self.assert_ok(self.invoke(project, run_root, auth, "grant-continuation", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "two"))
            events = [json.loads(line) for line in (run_root / "events.jsonl").read_text().splitlines()]
            grant = next(event for event in events if event["type"] == "continuation_granted")
            self.assertEqual("policy", grant["source"])

    def test_tampering_and_project_scope_drift_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-2"))
            events = run_root / "events.jsonl"
            record = json.loads(events.read_text())
            record["run_id"] = "forged"
            events.write_text(json.dumps(record) + "\n")
            rejected = self.invoke(project, run_root, auth, "select", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)
            other = Path(tmp) / "other"
            other.mkdir()
            rejected = self.invoke(other, run_root, auth, "select", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)

    def test_auto_gate_decision_is_recorded_in_existing_ledger(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-gate"))
            result = self.assert_ok(
                self.invoke(
                    project,
                    run_root,
                    auth,
                    "resolve-gate",
                    "-GateId",
                    "project_issue_resolution_route",
                    "-Recommendation",
                    "Project Resolve",
                )
            )
            self.assertEqual("Project Resolve", result["decision"]["selected_option"])
            self.assertEqual("project_issue_resolution_route", result["projection"]["gate_decisions"][0]["gate_id"])

    def test_auto_rejects_caller_selected_gate_answer(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-gate"))
            rejected = self.invoke(
                project,
                run_root,
                auth,
                "resolve-gate",
                "-GateId",
                "project_issue_resolution_route",
                "-Recommendation",
                "Project Resolve",
                "-SelectedOption",
                "Project Orchestrate",
            )
            self.assertNotEqual(0, rejected.returncode)

    def test_gate_resolution_rejects_unknown_or_caller_widened_contracts(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-contract"))
            unknown = self.invoke(project, run_root, auth, "resolve-gate", "-GateId", "forged", "-Recommendation", "Merge")
            self.assertNotEqual(0, unknown.returncode)
            widened = self.invoke(project, run_root, auth, "resolve-gate", "-GateId", "project_issue_resolution_route", "-OptionsJson", '["forged"]', "-Recommendation", "forged")
            self.assertNotEqual(0, widened.returncode)

    def test_failed_or_stale_loop_evidence_cannot_grant_continuation(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "looping")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "loop-proof"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "accept", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "verify", "-Candidate", "one"))
            budget, health = self.loop_evidence(project, "one", budget_ok=False)
            rejected = self.invoke(project, run_root, auth, "recheck-budget", "-Candidate", "one", "-BudgetEvidencePath", str(budget), "-HealthEvidencePath", str(health))
            self.assertNotEqual(0, rejected.returncode)
            budget, health = self.loop_evidence(project, "one")
            self.assert_ok(self.invoke(project, run_root, auth, "recheck-budget", "-Candidate", "one", "-BudgetEvidencePath", str(budget), "-HealthEvidencePath", str(health)))
            health.write_text(json.dumps({"candidate_id": "one", "verifier_type": "independent", "independent": True, "proof": [{"command": "focused tests", "ok": False, "artifact": "changed"}]}), encoding="utf-8")
            rejected = self.invoke(project, run_root, auth, "grant-continuation", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)

    def test_terminal_runs_reject_more_gate_or_stop_events(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "auto")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "auto-terminal"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "accept", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "verify", "-Candidate", "one"))
            self.assert_ok(self.invoke(project, run_root, auth, "complete", "-Claim", "outcome"))
            gate = self.invoke(project, run_root, auth, "resolve-gate", "-GateId", "project_issue_resolution_route", "-Recommendation", "Project Resolve")
            stop = self.invoke(project, run_root, auth, "block", "-Reason", "late")
            self.assertNotEqual(0, gate.returncode)
            self.assertNotEqual(0, stop.returncode)


if __name__ == "__main__":
    unittest.main()
