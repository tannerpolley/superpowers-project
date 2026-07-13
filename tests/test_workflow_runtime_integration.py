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

    def fixture(self, root: Path, mode: str) -> tuple[Path, Path, Path]:
        project = root / "project"
        project.mkdir()
        run_root = project / ".superpowers" / "runs" / "trial"
        authorization = project / "authorization.json"
        authorization.write_text(
            json.dumps(
                {
                    "source": "trial-fixture",
                    "mode": mode,
                    "repo_root": str(project.resolve()),
                    "candidate_scope": ["one"] if mode == "auto" else ["one", "two"],
                }
            )
        )
        return project, run_root, authorization

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

    def test_loop_requires_all_iteration_gates_before_second_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            project, run_root, auth = self.fixture(Path(tmp), "looping")
            self.assert_ok(self.invoke(project, run_root, auth, "start", "-RunId", "loop-1"))
            self.assert_ok(self.invoke(project, run_root, auth, "select", "-Candidate", "one"))
            rejected = self.invoke(project, run_root, auth, "select", "-Candidate", "two")
            self.assertNotEqual(0, rejected.returncode)
            rejected = self.invoke(project, run_root, auth, "grant-continuation", "-Candidate", "one")
            self.assertNotEqual(0, rejected.returncode)
            for action in ("accept", "verify", "recheck-budget", "grant-continuation"):
                self.assert_ok(self.invoke(project, run_root, auth, action, "-Candidate", "one"))
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
                    "issue-route",
                    "-OptionsJson",
                    '["direct", "issue"]',
                    "-Recommendation",
                    "issue",
                )
            )
            self.assertEqual("issue", result["decision"]["selected_option"])
            self.assertEqual("issue-route", result["projection"]["gate_decisions"][0]["gate_id"])

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
                "issue-route",
                "-OptionsJson",
                '["direct", "issue"]',
                "-Recommendation",
                "direct",
                "-SelectedOption",
                "issue",
            )
            self.assertNotEqual(0, rejected.returncode)


if __name__ == "__main__":
    unittest.main()
