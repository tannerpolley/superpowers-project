from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from scripts.lib.evidence_schema import (
    EvidenceError,
    EvidenceKindRegistration,
    RuleResult,
    build_envelope_hash,
    canonical_json,
    hash_ref,
    parse_envelope_json,
    register_evidence_kind,
    register_provider_evidence_kind,
)
from scripts.lib.gate_receipts import build_receipt, verify_receipt


def git(root: Path, *args: str) -> str:
    process = subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True)
    return process.stdout.strip()


def file_hash(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def make_repository() -> Path:
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


def make_envelope(root: Path, *, plan_path: str = "docs/superpowers/plans/plan.md") -> dict[str, object]:
    plan = root / plan_path
    common = Path(git(root, "rev-parse", "--git-common-dir"))
    if not common.is_absolute():
        common = root / common
    common = common.resolve()
    envelope: dict[str, object] = {
        "schema_version": 1,
        "gate": "pr_ready",
        "repository": {
            "root": str(root.resolve()),
            "git_common_dir": str(common),
            "remote_identity": None,
        },
        "workflow": {
            "run_id": "run-1",
            "candidate_id": "candidate-1",
            "mode": "manual",
            "authorization_hash": hash_ref({"run_id": "run-1", "candidate_id": "candidate-1"}),
        },
        "source": {
            "spec_path": None,
            "spec_hash": None,
            "plan_path": plan_path,
            "plan_hash": file_hash(plan),
        },
        "target": {
            "task_id": None,
            "workspace_id": "local-checkout",
            "branch": git(root, "branch", "--show-current"),
        },
        "evidence": [
            {
                "kind": "git_state",
                "collector": "git-state@1",
                "observed_at": "2026-07-10T12:00:00Z",
                "payload": {"head": git(root, "rev-parse", "HEAD"), "status_exit_code": 0},
            }
        ],
        "prior_event_hash": None,
    }
    for item in envelope["evidence"]:  # type: ignore[union-attr]
        item["payload_hash"] = hash_ref(item["payload"])
    envelope["envelope_hash"] = build_envelope_hash(envelope)
    return envelope


class EvidenceSchemaTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repository()
        self.addCleanup(lambda: __import__("shutil").rmtree(self.repo, ignore_errors=True))

    def test_hash_is_stable_and_duplicate_keys_fail(self):
        envelope = make_envelope(self.repo)
        first = parse_envelope_json(json.dumps(envelope), self.repo)
        second = parse_envelope_json(json.dumps(envelope, indent=2), self.repo)
        self.assertEqual(first.envelope_hash, second.envelope_hash)
        with self.assertRaisesRegex(EvidenceError, "duplicate_key"):
            parse_envelope_json('{"schema_version":1,"schema_version":1}', self.repo)

    def test_paths_must_resolve_inside_repository(self):
        (self.repo.parent / "outside.md").write_text("outside\n", encoding="utf-8")
        envelope = make_envelope(self.repo, plan_path="../outside.md")
        with self.assertRaisesRegex(EvidenceError, "repository_mismatch"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_symlink_escape_is_rejected(self):
        outside = self.repo.parent / "outside-plan.md"
        outside.write_text("outside\n", encoding="utf-8")
        link = self.repo / "docs" / "superpowers" / "plans" / "linked.md"
        link.symlink_to(outside)
        envelope = make_envelope(self.repo, plan_path="docs/superpowers/plans/linked.md")
        with self.assertRaisesRegex(EvidenceError, "repository_mismatch"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_invalid_hashes_and_unknown_fields_fail_closed(self):
        envelope = make_envelope(self.repo)
        envelope["workflow"]["authorization_hash"] = "a" * 64  # type: ignore[index]
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_canonical_json_rejects_non_finite_and_non_json_values(self):
        for value in (float("nan"), float("inf"), float("-inf"), {"nested": [float("nan")]}):
            with self.subTest(value=repr(value)):
                with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
                    canonical_json(value)
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            canonical_json({"unsupported": {"a", "b"}})
        envelope = make_envelope(self.repo)
        envelope["workflow"]["untrusted_success"] = True  # type: ignore[index]
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_payload_and_envelope_tampering_fail_closed(self):
        envelope = make_envelope(self.repo)
        envelope["evidence"][0]["payload"]["head"] = "forged"  # type: ignore[index]
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_impossible_observation_timestamp_fails_closed(self):
        envelope = make_envelope(self.repo)
        envelope["evidence"][0]["observed_at"] = "9999-99-99T99:99:99Z"  # type: ignore[index]
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            parse_envelope_json(json.dumps(envelope), self.repo)
        envelope = make_envelope(self.repo)
        envelope["envelope_hash"] = hash_ref({"forged": True})
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            parse_envelope_json(json.dumps(envelope), self.repo)

    def test_registered_evidence_kind_round_trips_and_receipt_is_bound(self):
        seen: list[dict[str, object]] = []

        def validate_workspace(payload):
            seen.append(dict(payload))
            if payload.get("provider") not in {"fixture", "codex"}:
                raise EvidenceError("schema_invalid", "workspace provider is invalid")

        register_provider_evidence_kind(EvidenceKindRegistration("workspace_receipt", "1", validate_workspace))
        envelope = make_envelope(self.repo)
        envelope["evidence"].append(  # type: ignore[union-attr]
            {
                "kind": "workspace_receipt",
                "collector": "registered-evidence@1",
                "observed_at": "2026-07-10T12:00:01Z",
                "payload": {"provider": "fixture", "workspace_id": "local-checkout"},
            }
        )
        envelope["evidence"][-1]["payload_hash"] = hash_ref(envelope["evidence"][-1]["payload"])  # type: ignore[index]
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        parsed = parse_envelope_json(json.dumps(envelope), self.repo)
        self.assertEqual([{"provider": "fixture", "workspace_id": "local-checkout"}], seen)
        from scripts.lib.gate_receipts import REQUIRED_RECEIPT_RULES
        complete_rules = [RuleResult(rule_id, True, "passed") for rule_id in sorted(REQUIRED_RECEIPT_RULES["pr_ready"])]
        receipt = build_receipt(parsed, "pr-ready-validator@1", {"head": parsed.target["branch"]}, complete_rules)
        verify_receipt(receipt, parsed, "pr_ready")
        forged_validator = build_receipt(parsed, "arbitrary-validator@999", {"head": parsed.target["branch"]}, [RuleResult("identity", True, "passed")])
        with self.assertRaisesRegex(EvidenceError, "validator"):
            verify_receipt(forged_validator, parsed, "pr_ready")
        tampered = replace(receipt, receipt_hash=hash_ref({"forged": True}))
        with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
            verify_receipt(tampered, parsed, "pr_ready")
        with self.assertRaisesRegex(EvidenceError, "duplicate_evidence_kind"):
            register_provider_evidence_kind(EvidenceKindRegistration("workspace_receipt", "1", validate_workspace))


if __name__ == "__main__":
    unittest.main()
