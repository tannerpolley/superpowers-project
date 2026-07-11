from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.lib.evidence_collectors import CollectionRequest, CollectorResult, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_bytes_ref, hash_ref, parse_envelope
from scripts.lib.gate_publish_ready import validate_publish_ready
from scripts.lib.gate_receipts import GateReceipt
from scripts.lib.package_provenance import runtime_contract_hash, runtime_manifest
import scripts.lib.evidence_collectors as evidence_collectors


ROOT = Path(__file__).parents[1]


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def package_hash(root: Path) -> str:
    return hash_ref([entry.to_dict() for entry in runtime_manifest(root)])


def release_envelope(root: Path) -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
    manifest = json.loads((root / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    package = package_hash(root)
    authorization = {
        "authorized": True,
        "scope": "publish_ready",
        "run_id": "run-1",
        "candidate_id": "candidate-1",
        "source_plan_hash": hash_bytes_ref((root / "docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md").read_bytes()),
        "package_hash": package,
    }
    request = CollectionRequest(
        gate="publish_ready",
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref(authorization)},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False, "installation_root": str(root.resolve()), "agent_trial_root": str((root / "tests/workflow-trials/receipts/current").resolve())},
        commands=("git_status", "source_validation", "sync_live_validation"),
            provider_inputs={
                "authorization": authorization,
                "package_observation_id": "package_current",
                "installation_observation_id": "installation_current",
                "agent_trial_observation_id": "agent_trials_current",
                "installation_root": str(root),
                "agent_trial_receipt_dir": "tests/workflow-trials/receipts/current",
            },
    )

    def trusted_command(_root: Path, command_id: str) -> CollectorResult:
        payload = {
            "argv": list(evidence_collectors.READ_ONLY_COMMANDS[command_id]),
            "exit_code": 0,
            "stdout_hash": hash_ref({"stdout": command_id}),
            "stderr_hash": hash_ref({"stderr": command_id}),
            "timed_out": False,
            "command_id": command_id,
        }
        return CollectorResult("command_result", "command-result@1", "2026-07-10T12:00:00Z", payload)

    with patch.object(evidence_collectors, "collect_command_result", side_effect=trusted_command):
        return build_evidence_envelope(request)


def write_receipt(root: Path, envelope: dict[str, object]) -> GateReceipt:
    receipt = validate_publish_ready(parse_envelope(envelope, root), root)
    path = root / ".superpowers" / "runs" / "publish-ready-receipt.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt.to_dict(), indent=2) + "\n", encoding="utf-8")
    return receipt


def run_prepare(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["SUPERPOWERS_VALIDATION_COLLECTION"] = "1"
    return subprocess.run(
        [str(ROOT / "scripts" / "prepare-release.sh"), "-RepoRoot", str(root), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=environment,
    )


@unittest.skipIf(os.environ.get("SUPERPOWERS_VALIDATION_COLLECTION") == "1", "release-gate tests are skipped inside their trusted validation subprocess")
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

    def test_prepare_release_rejects_substituted_root_options(self):
        write_receipt(self.repo, release_envelope(self.repo))
        result = run_prepare(self.repo, "-PublishReadyReceiptPath", ".superpowers/runs/publish-ready-receipt.json", "-LivePluginRoot", str(self.repo / "other-install"))
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("repository_mismatch", json.loads(result.stdout)["error"]["code"])

    def test_prepare_release_rejects_a_self_hashed_receipt_with_forged_rules(self):
        receipt = write_receipt(self.repo, release_envelope(self.repo)).to_dict()
        receipt["rules"] = [{"rule_id": "forged", "ok": True, "reason": "forged"}]
        receipt.pop("receipt_hash")
        from scripts.lib.evidence_schema import hash_ref
        receipt["receipt_hash"] = hash_ref({key: value for key, value in receipt.items()})
        path = self.repo / ".superpowers" / "runs" / "forged-receipt.json"
        path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        result = run_prepare(self.repo, "-PublishReadyReceiptPath", ".superpowers/runs/forged-receipt.json", "-LivePluginRoot", str(self.repo), "-AgentReceiptDir", "tests/workflow-trials/receipts/current")
        self.assertNotEqual(0, result.returncode)
        self.assertIn(json.loads(result.stdout)["error"]["code"], {"receipt_stale", "required_rule_failed"})

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

    def test_publish_ready_rejects_failed_sync_command(self):
        envelope = release_envelope(self.repo)
        command = next(item for item in envelope["evidence"] if item.get("payload", {}).get("command_id") == "sync_live_validation")
        command["payload"]["exit_code"] = 1
        command["payload_hash"] = hash_ref(command["payload"])
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_requires_trusted_validation_and_sync_commands(self):
        envelope = release_envelope(self.repo)
        envelope["evidence"] = [item for item in envelope["evidence"] if item.get("payload", {}).get("command_id") not in {"source_validation", "sync_live_validation"}]
        envelope["envelope_hash"] = build_envelope_hash(envelope)
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

    def test_publish_ready_rejects_wrong_manifest_version_or_installation_path(self):
        for field, value in (("manifest_version", "forged"), ("current_version", "forged"), ("installation_root", "/tmp/forged-install")):
            with self.subTest(field=field):
                envelope = release_envelope(self.repo)
                item = next(item for item in envelope["evidence"] if item["kind"] == "installation_state")
                item["payload"][field] = value
                item["payload_hash"] = hash_ref(item["payload"])
                envelope["envelope_hash"] = build_envelope_hash(envelope)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_hardcoded_trial_counters_or_forged_receipt_hash(self):
        for field, value in (("tool_calls", [{"name": "forged"}]), ("external_mutations", 99), ("receipt_hashes", [hash_ref({"forged": True})])):
            with self.subTest(field=field):
                envelope = release_envelope(self.repo)
                item = next(item for item in envelope["evidence"] if item["kind"] == "agent_trial")
                item["payload"][field] = value
                item["payload_hash"] = hash_ref(item["payload"])
                envelope["envelope_hash"] = build_envelope_hash(envelope)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_requires_explicit_publish_authorization_bindings(self):
        envelope = release_envelope(self.repo)
        item = next(item for item in envelope["evidence"] if item["kind"] == "authorization_event")
        item["payload"]["event"].pop("scope")
        item["payload_hash"] = hash_ref(item["payload"])
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_publish_ready_rejects_substituted_bound_installation_or_trial_root(self):
        for field, value in (("installation_root", str((self.repo / "other-install").resolve())), ("agent_trial_root", str((self.repo / "other-trials").resolve()))):
            with self.subTest(field=field):
                envelope = release_envelope(self.repo)
                envelope["target"][field] = value
                envelope["envelope_hash"] = build_envelope_hash(envelope)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed|repository_mismatch"):
                    validate_publish_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_prepare_release_rejects_uncommitted_package_change_after_receipt(self):
        receipt = write_receipt(self.repo, release_envelope(self.repo))
        script = self.repo / "scripts" / "workflow-run.sh"
        script.write_text(script.read_text(encoding="utf-8") + "\n# stale after receipt\n", encoding="utf-8")
        result = run_prepare(self.repo, "-PublishReadyReceiptPath", ".superpowers/runs/publish-ready-receipt.json", "-LivePluginRoot", str(self.repo), "-AgentReceiptDir", "tests/workflow-trials/receipts/current")
        self.assertNotEqual(0, result.returncode)
        self.assertIn(json.loads(result.stdout)["error"]["code"], {"receipt_stale", "artifact_hash_mismatch"})

    def test_publish_collection_rejects_caller_supplied_package_install_and_trial_payloads(self):
        request = CollectionRequest(
            gate="publish_ready",
            repository_root=self.repo,
            workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True})},
            source={"spec_path": None, "plan_path": "docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md"},
            target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
            commands=("git_status",),
            provider_inputs={
                "authorization": {"authorized": True},
                "package": {"package_hash": "forged"},
                "installation": {"package_hash": "forged"},
                "agent_trial": {"tool_calls": [{"name": "forged"}], "receipt_hashes": []},
            },
        )
        with self.assertRaisesRegex(EvidenceError, "collector_untrusted"):
            build_evidence_envelope(request)


if __name__ == "__main__":
    unittest.main()
