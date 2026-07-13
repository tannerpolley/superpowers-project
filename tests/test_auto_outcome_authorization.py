from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
AUTO_VALIDATOR = ROOT / "scripts" / "validate-auto-mode-authorization.sh"
MODE_VALIDATOR = ROOT / "scripts" / "validate-workflow-mode-ledger.sh"


class AutoOutcomeAuthorizationTests(unittest.TestCase):
    def ledger(self, repo: Path) -> dict:
        return {
            "question_id": "project_workflow_mode",
            "source": "trial-fixture",
            "selected_mode": "auto",
            "repo_root": str(repo.resolve()),
            "request_fingerprint": hashlib.sha256(b"raw request").hexdigest(),
            "autonomy_scope": "one-outcome-lifecycle",
            "candidate_scope": ["raw-request"],
            "route_policy": {
                "selected_mode": "agent-chooses",
                "issue_route": "evidence-based",
                "one_outcome_only": True,
                "continue_to_next_candidate": False,
            },
            "merge_permission": {
                "selected_mode": "preauthorized-after-clean-premerge",
                "require_clean_premerge": True,
            },
            "mutation_scope": ["current-repo", "development-branch"],
            "required_proof": [
                "plan-proof-oracle",
                "verification-receipts",
                "cleanup-hook",
                "premerge-proof",
                "closeout-proof",
            ],
            "stop_conditions": [
                "missing-proof",
                "dirty-unsafe-state",
                "failed-validation",
                "decision-outside-policy",
            ],
        }

    def invoke(self, script: Path, repo: Path, ledger: Path) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ, SUPERPOWERS_TRIAL_NONINTERACTIVE="1")
        argument = "-AuthorizationPath" if script == AUTO_VALIDATOR else "-ModeLedgerPath"
        return subprocess.run(
            ["bash", str(script), "-RepoRoot", str(repo), argument, str(ledger)],
            cwd="/tmp",
            env=env,
            text=True,
            capture_output=True,
        )

    def test_raw_request_auto_uses_startup_mode_without_source_spec(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            path = repo / "mode.json"
            path.write_text(json.dumps(self.ledger(repo)), encoding="utf-8")
            result = self.invoke(AUTO_VALIDATOR, repo, path)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_old_second_question_authorization_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            ledger = self.ledger(repo)
            ledger["question_id"] = "project_auto_mode_authorization"
            ledger["source_spec"] = "docs/superpowers/specs/source.md"
            path = repo / "mode.json"
            path.write_text(json.dumps(ledger), encoding="utf-8")
            result = self.invoke(AUTO_VALIDATOR, repo, path)
            self.assertNotEqual(0, result.returncode)

    def test_workflow_mode_validator_accepts_one_outcome_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            ledger = self.ledger(repo)
            ledger.update(
                {
                    "plugin_manifest_version": "fixture",
                    "plugin_contract_hash": "fixture",
                    "started_at": "2026-07-13T00:00:00Z",
                    "proof_policy": {"required": True},
                    "downstream_ledger_paths": [".superpowers/runs/run"],
                }
            )
            path = repo / "mode.json"
            path.write_text(json.dumps(ledger), encoding="utf-8")
            result = self.invoke(MODE_VALIDATOR, repo, path)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_workflow_contract_has_one_auto_startup_question(self):
        contract = yaml.safe_load((ROOT / "docs/superpowers/workflow-contract.yml").read_text(encoding="utf-8"))
        route = contract["workflow_skills"]["initiate-workflow"]
        self.assertIn("project_workflow_mode", route["question_ids"])
        self.assertNotIn("project_auto_mode_authorization", route["question_ids"])
        self.assertNotIn(
            "project_auto_mode_authorization",
            {gate["question_id"] for gate in route["gates"]},
        )


if __name__ == "__main__":
    unittest.main()
