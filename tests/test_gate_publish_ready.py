from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_publish_ready import validate_publish_ready
from scripts.lib.gate_receipts import GateReceipt
from scripts.lib.package_provenance import runtime_contract_hash, runtime_manifest


ROOT = Path(__file__).parents[1]


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def package_hash(root: Path) -> str:
    return hash_ref([entry.to_dict() for entry in runtime_manifest(root)])


def release_envelope(root: Path) -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
    manifest = json.loads((root / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    package = package_hash(root)
    return build_evidence_envelope(CollectionRequest(
        gate="publish_ready",
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True})},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "authorization": {"authorized": True},
            "package": {"package_hash": package, "contract_hash": runtime_contract_hash(root), "manifest_version": manifest["version"], "commit": head, "revision_classification": "runtime"},
            "installation": {"package_hash": package, "manifest_version": manifest["version"], "commit": head, "source": "current"},
            "agent_trial": {"package_hash": package, "tool_calls": [{"name": "validate-pr-ready"}], "external_mutations": 0, "receipt_hashes": [hash_ref({"trial": "receipt"})]},
        },
    ))


def write_receipt(root: Path, envelope: dict[str, object]) -> GateReceipt:
    receipt = validate_publish_ready(parse_envelope(envelope, root), root)
    path = root / ".superpowers" / "runs" / "publish-ready-receipt.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt.to_dict(), indent=2) + "\n", encoding="utf-8")
    return receipt


def run_prepare(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(ROOT / "scripts" / "prepare-release.sh"), "-RepoRoot", str(root), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


class PublishReadyGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp()) / "repo"
        shutil.copytree(ROOT, self.repo, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
        for receipt_path in (self.repo / "tests" / "workflow-trials" / "receipts" / "current").glob("**/receipt.json"):
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            receipt["package_hash"] = runtime_contract_hash(self.repo)
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "fixture@example.com")
        git(self.repo, "config", "user.name", "Fixture")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "fixture")
        self.addCleanup(lambda: shutil.rmtree(self.repo.parent, ignore_errors=True))

    def test_publish_ready_accepts_current_package_installation_and_trial_proof(self):
        receipt = validate_publish_ready(parse_envelope(release_envelope(self.repo), self.repo), self.repo)
        self.assertEqual("publish_ready", receipt.gate)
        self.assertEqual("passed", receipt.disposition)

    def test_publish_ready_rejects_stale_package_hash(self):
        envelope = release_envelope(self.repo)
        script = self.repo / "scripts" / "workflow-run.sh"
        script.write_text(script.read_text(encoding="utf-8") + "\n# changed\n", encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_prepare_release_requires_a_publish_ready_receipt_with_structured_error(self):
        result = run_prepare(self.repo)
        self.assertNotEqual(0, result.returncode)
        payload = json.loads(result.stdout)
        self.assertEqual("evidence_missing", payload["error"]["code"])

    def test_prepare_release_check_only_never_claims_publish_ready(self):
        result = run_prepare(self.repo, "-CheckOnly")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertFalse(payload["publish_ready"])
        self.assertIsNone(payload["publish_ready_receipt_hash"])

    def test_prepare_release_collect_only_writes_a_publish_ready_envelope(self):
        output = ".superpowers/runs/publish-ready-envelope.json"
        result = run_prepare(
            self.repo,
            "-CollectOnly",
            "-OutputPath",
            output,
            "-LivePluginRoot",
            str(self.repo),
            "-AuthorizationJson",
            json.dumps({"authorized": True, "scope": "publish_ready"}),
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual("collect-publish-ready", payload["phase"])
        envelope = json.loads((self.repo / output).read_text(encoding="utf-8"))
        self.assertEqual("publish_ready", envelope["gate"])

    def test_prepare_release_consumes_current_receipt_and_reports_hash(self):
        receipt = write_receipt(self.repo, release_envelope(self.repo))
        result = run_prepare(
            self.repo,
            "-PublishReadyReceiptPath",
            ".superpowers/runs/publish-ready-receipt.json",
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["publish_ready"])
        self.assertEqual(receipt.receipt_hash, payload["publish_ready_receipt_hash"])

    def test_publish_ready_rejects_missing_installation_evidence(self):
        envelope = release_envelope(self.repo)
        envelope["evidence"] = [item for item in envelope["evidence"] if item["kind"] != "installation_state"]
        envelope["envelope_hash"] = __import__("scripts.lib.evidence_schema", fromlist=["build_envelope_hash"]).build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "missing evidence:.*installation_state"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_failed_validation_command(self):
        envelope = release_envelope(self.repo)
        command = next(item for item in envelope["evidence"] if item["kind"] == "command_result")
        command["payload"]["exit_code"] = 1
        command["payload_hash"] = hash_ref(command["payload"])
        envelope["envelope_hash"] = __import__("scripts.lib.evidence_schema", fromlist=["build_envelope_hash"]).build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_dirty_checkout_after_collection(self):
        envelope = release_envelope(self.repo)
        (self.repo / "dirty.txt").write_text("dirty\n", encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_stale_commit(self):
        envelope = release_envelope(self.repo)
        (self.repo / "stale.txt").write_text("new commit\n", encoding="utf-8")
        git(self.repo, "add", "stale.txt")
        git(self.repo, "-c", "user.email=fixture@example.com", "-c", "user.name=Fixture", "commit", "-qm", "new commit")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_invalid_package_provenance(self):
        envelope = release_envelope(self.repo)
        package = next(item for item in envelope["evidence"] if item["kind"] == "package_provenance")
        package["payload"]["revision_classification"] = "historical"
        package["payload_hash"] = hash_ref(package["payload"])
        envelope["envelope_hash"] = __import__("scripts.lib.evidence_schema", fromlist=["build_envelope_hash"]).build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)


if __name__ == "__main__":
    unittest.main()
