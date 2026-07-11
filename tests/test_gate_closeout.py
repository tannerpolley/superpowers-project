from __future__ import annotations

import shutil
import json
import subprocess
import tempfile
import unittest
import contextlib
import io
from dataclasses import replace
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, RuleResult, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_receipts import EXPECTED_VALIDATORS, REQUIRED_RECEIPT_RULES, build_receipt
from scripts.lib.command_support import Context
from scripts.lib.commands.gates import command_validate_resolve_terminal_closeout


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "Fixture")
    plan = root / "docs" / "superpowers" / "plans" / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(root, "add", ".")
    git(root, "commit", "-qm", "fixture")
    return root


def request(root: Path, gate: str, *, prior: str | None = None) -> dict[str, object]:
    return build_evidence_envelope(CollectionRequest(
        gate=gate,
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True})},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True},
            "integration": {"integrated": True, "head": git(root, "rev-parse", "HEAD")},
            "cleanup": {"status_exit_code": 0, "dirty": False, "owner": "fixture", "task_owned_paths": []},
        },
        prior_event_hash=prior,
    ))


def merge_prior(root: Path):
    base = parse_envelope(request(root, "pr_ready"), root)
    merge_envelope = replace(base, gate="merge_decision")
    rules = [RuleResult(rule_id, True, "observed") for rule_id in sorted(REQUIRED_RECEIPT_RULES["merge_decision"])]
    return build_receipt(merge_envelope, EXPECTED_VALIDATORS["merge_decision"], {"head": git(root, "rev-parse", "HEAD"), "branch": "main"}, rules)


class CloseoutGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def test_closeout_requires_prior_pr_ready_receipt(self):
        envelope = parse_envelope(request(self.repo, "closeout"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_closeout(envelope, self.repo, None)

    def test_public_closeout_launcher_fails_without_evidence(self):
        root = Path(__file__).parents[1]
        process = subprocess.run(["bash", str(root / "skills/merge-changes/scripts/closeout.sh")], cwd=root, text=True, capture_output=True)
        self.assertNotEqual(0, process.returncode)
        self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])

    def test_closeout_accepts_current_prior_receipt_and_emits_rules(self):
        prior = merge_prior(self.repo)
        closeout = parse_envelope(request(self.repo, "closeout", prior=prior.receipt_hash), self.repo)
        receipt = validate_closeout(closeout, self.repo, prior)
        self.assertEqual("closeout", receipt.gate)
        self.assertEqual("passed", receipt.disposition)
        self.assertTrue({rule.rule_id for rule in receipt.rules} >= {"integration_proof", "completion_state", "workspace_disposition", "cleanup_state"})

    def test_closeout_rejects_forged_prior_validator_and_bindings(self):
        pr_request = request(self.repo, "pr_ready")
        pr_envelope = parse_envelope(pr_request, self.repo)
        pr_receipt = validate_pr_ready(pr_envelope, self.repo)
        forged = __import__("dataclasses").replace(pr_receipt, validator_id="arbitrary-validator@999")
        forged = __import__("dataclasses").replace(forged, receipt_hash=hash_ref(forged.unsigned_dict()))
        closeout = parse_envelope(request(self.repo, "closeout", prior=forged.receipt_hash), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_closeout(closeout, self.repo, forged)

    def test_closeout_rejects_stale_integration_head(self):
        prior = merge_prior(self.repo)
        envelope = request(self.repo, "closeout", prior=prior.receipt_hash)
        integration = next(item for item in envelope["evidence"] if item["kind"] == "integration_state")
        integration["payload"]["head"] = "stale-head"
        integration["payload_hash"] = hash_ref(integration["payload"])
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_closeout(parse_envelope(envelope, self.repo), self.repo, prior)

    def test_terminal_decision_is_bound_to_run_candidate_and_authorization(self):
        pr_receipt = validate_pr_ready(parse_envelope(request(self.repo, "pr_ready"), self.repo), self.repo)
        closeout = request(self.repo, "closeout", prior=pr_receipt.receipt_hash)
        root = Path(__file__).parents[1]
        ctx = Context(root / "skills/resolve-issue/scripts/validate-terminal-closeout.sh", self.repo, "skills/resolve-issue/scripts/validate-terminal-closeout.sh", "validate-terminal-closeout.sh", [], root, self.repo)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = command_validate_resolve_terminal_closeout(ctx, {"RepoRoot": str(self.repo), "EvidenceEnvelopeJson": json.dumps(closeout), "PriorReceiptJson": json.dumps(pr_receipt.to_dict()), "ContinuationDecisionJson": json.dumps({"terminal_state": "done", "run_id": "run-1", "candidate_id": "wrong-candidate", "authorization_hash": hash_ref({"authorized": True})})})
        self.assertNotEqual(0, status)
        self.assertEqual("candidate_mismatch", json.loads(output.getvalue())["error"]["code"])


if __name__ == "__main__":
    unittest.main()
