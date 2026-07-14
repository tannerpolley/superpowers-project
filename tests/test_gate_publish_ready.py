from __future__ import annotations

import json
import hashlib
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
from scripts.lib.workflow_state import append_event
from scripts.lib.commands.distribution import ReleaseEvidenceError, base_release_tag, validate_dependency_pins
import scripts.lib.evidence_collectors as evidence_collectors


ROOT = Path(__file__).parents[1]
TRIAL_RECEIPTS = Path(".superpowers/runs/agent-trials/current")


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def package_hash(root: Path) -> str:
    return hash_ref([entry.to_dict() for entry in runtime_manifest(root)])


def write_trial_receipts(root: Path) -> None:
    receipt_paths = []
    package = runtime_contract_hash(root)
    for scenario, repetitions in (("auto-golden", 5), ("loop-adversarial", 3)):
        for repetition in range(1, repetitions + 1):
            name = f"{scenario}-{repetition}"
            trial_root = root / TRIAL_RECEIPTS / "runs" / name
            project_root = trial_root / "project"
            result = project_root / "result.txt"
            result.parent.mkdir(parents=True, exist_ok=True)
            result.write_text("complete\n", encoding="utf-8")
            run_root = project_root / ".superpowers" / "runs" / name
            append_event(run_root, {"type": "run_started", "run_id": name})
            append_event(run_root, {"type": "candidate_selected", "candidate": "one"})
            append_event(run_root, {"type": "mutation_applied", "candidate": "one"})
            if scenario == "auto-golden":
                append_event(run_root, {"type": "candidate_accepted", "candidate": "one"})
                append_event(run_root, {"type": "verifier_passed", "candidate": "one"})
                append_event(run_root, {"type": "gate_resolved", "gate_id": "project_merge_final_health_gate", "selected_option": "Done", "source": "policy"})
                append_event(run_root, {"type": "run_completed", "claim": "outcome", "candidate": "one"})
            ledger = run_root / "events.jsonl"
            last_hash = json.loads(ledger.read_text(encoding="utf-8").splitlines()[-1])["hash"]
            expected = "pass" if scenario == "auto-golden" else "blocked"
            receipt = {
                "schema_version": 1,
                "trial_id": name,
                "scenario": scenario,
                "repetition": repetition,
                "worker": {"id": f"00000000-0000-4000-8000-{repetition:012d}"},
                "verifier": {"id": f"00000000-0000-4001-8000-{repetition:012d}"},
                "package_hash": package,
                "trial_root": trial_root.relative_to(root).as_posix(),
                "project_root": project_root.relative_to(root).as_posix(),
                "expected_outcome": expected,
                "observed_outcome": expected,
                "friction": 1,
                "user_input_calls": 0,
                "external_mutations": 0,
                "repository_evidence": [{"path": "result.txt", "sha256": hashlib.sha256(result.read_bytes()).hexdigest()}],
                "event_ledger": {"path": ledger.relative_to(project_root).as_posix(), "last_hash": last_hash},
                "worker_claim": {"result": "complete"},
                "verifier_decision": expected,
            }
            receipt_path = trial_root / "receipt.json"
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            receipt_paths.append(receipt_path.relative_to(root).as_posix())
    index = root / TRIAL_RECEIPTS / "receipt-index.json"
    index.write_text(json.dumps({"package_hash": package, "receipts": sorted(receipt_paths)}, indent=2) + "\n", encoding="utf-8")


def release_envelope(root: Path) -> dict[str, object]:
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
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False, "installation_root": str(root.resolve()), "agent_trial_root": str((root / TRIAL_RECEIPTS).resolve())},
        commands=("git_status", "source_validation", "sync_live_validation"),
            provider_inputs={
                "authorization": authorization,
                "package_observation_id": "package_current",
                "installation_observation_id": "installation_current",
                "agent_trial_observation_id": "agent_trials_current",
                "installation_root": str(root),
                "agent_trial_receipt_dir": TRIAL_RECEIPTS.as_posix(),
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


def evidence_item(envelope: dict[str, object], kind: str) -> dict[str, object]:
    return next(item for item in envelope["evidence"] if item["kind"] == kind)


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
    def test_release_tags_and_dependencies_are_reproducible(self):
        self.assertEqual([], validate_dependency_pins(ROOT / "requirements-validation.txt"))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "requirements.txt"
            path.write_text("PyYAML>=6\n", encoding="utf-8")
            self.assertTrue(validate_dependency_pins(path))
        self.assertEqual("v0.3.0", base_release_tag("0.3.0+codex.local"))
        with self.assertRaises(ReleaseEvidenceError):
            base_release_tag("0.3")

    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp()) / "repo"
        shutil.copytree(ROOT, self.repo, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
        write_trial_receipts(self.repo)
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
        result = run_prepare(self.repo, "-PublishReadyReceiptPath", ".superpowers/runs/forged-receipt.json", "-LivePluginRoot", str(self.repo), "-AgentReceiptDir", TRIAL_RECEIPTS.as_posix())
        self.assertNotEqual(0, result.returncode)
        self.assertIn(json.loads(result.stdout)["error"]["code"], {"receipt_stale", "required_rule_failed"})

    def test_publish_ready_rejects_tampered_or_substituted_evidence(self):
        cases = (
            ("remove_kind", "installation_state", None, None, "missing evidence"),
            ("remove_commands", None, None, None, "required_rule_failed"),
            ("payload", "package_provenance", "revision_classification", "historical", "required_rule_failed"),
            ("payload", "installation_state", "manifest_version", "forged", "required_rule_failed"),
            ("payload", "installation_state", "current_version", "forged", "required_rule_failed"),
            ("payload", "installation_state", "installation_root", "/tmp/forged-install", "required_rule_failed"),
            ("payload", "agent_trial", "tool_calls", [{"name": "forged"}], "required_rule_failed"),
            ("payload", "agent_trial", "external_mutations", 99, "required_rule_failed"),
            ("payload", "agent_trial", "receipt_hashes", [hash_ref({"forged": True})], "required_rule_failed"),
            ("authorization_pop", "authorization_event", "scope", None, "required_rule_failed"),
            ("target", None, "installation_root", "other-install", "required_rule_failed|repository_mismatch"),
            ("target", None, "agent_trial_root", "other-trials", "required_rule_failed|repository_mismatch"),
        )
        for action, kind, field, value, pattern in cases:
            with self.subTest(action=action, kind=kind, field=field):
                envelope = release_envelope(self.repo)
                if action == "remove_kind":
                    envelope["evidence"] = [item for item in envelope["evidence"] if item["kind"] != kind]
                elif action == "remove_commands":
                    envelope["evidence"] = [
                        item for item in envelope["evidence"]
                        if item.get("payload", {}).get("command_id") not in {"source_validation", "sync_live_validation"}
                    ]
                elif action == "target":
                    envelope["target"][field] = str((self.repo / value).resolve())
                else:
                    item = evidence_item(envelope, kind)
                    if action == "authorization_pop":
                        item["payload"]["event"].pop(field)
                    else:
                        item["payload"][field] = value
                    item["payload_hash"] = hash_ref(item["payload"])
                envelope["envelope_hash"] = build_envelope_hash(envelope)
                with self.assertRaisesRegex(EvidenceError, pattern):
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

    def test_prepare_release_rejects_uncommitted_package_change_after_receipt(self):
        write_receipt(self.repo, release_envelope(self.repo))
        script = self.repo / "scripts" / "workflow-run.sh"
        script.write_text(script.read_text(encoding="utf-8") + "\n# stale after receipt\n", encoding="utf-8")
        result = run_prepare(self.repo, "-PublishReadyReceiptPath", ".superpowers/runs/publish-ready-receipt.json", "-LivePluginRoot", str(self.repo), "-AgentReceiptDir", TRIAL_RECEIPTS.as_posix())
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
