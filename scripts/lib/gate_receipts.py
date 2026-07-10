"""Canonical hash-bound gate receipts and receipt consumers."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping

from .evidence_schema import EvidenceEnvelope, EvidenceError, HashRef, RuleResult, canonical_json, hash_ref, is_hash_ref


@dataclass(frozen=True)
class GateReceipt:
    schema_version: int
    gate: str
    validator_id: str
    envelope_hash: HashRef
    bindings: Mapping[str, object]
    observations: Mapping[str, object]
    rules: tuple[RuleResult, ...]
    disposition: str
    receipt_hash: HashRef

    def unsigned_dict(self) -> dict[str, object]:
        return {
            "schema_version": self.schema_version,
            "gate": self.gate,
            "validator_id": self.validator_id,
            "envelope_hash": self.envelope_hash,
            "bindings": dict(self.bindings),
            "observations": dict(self.observations),
            "rules": [rule.to_dict() for rule in self.rules],
            "disposition": self.disposition,
        }

    def to_dict(self) -> dict[str, object]:
        result = self.unsigned_dict()
        result["receipt_hash"] = self.receipt_hash
        return result


def _receipt_hash(receipt: GateReceipt) -> HashRef:
    return hash_ref(receipt.unsigned_dict())


def build_receipt(
    envelope: EvidenceEnvelope,
    validator_id: str,
    observations: Mapping[str, object],
    rules: list[RuleResult],
) -> GateReceipt:
    if not rules:
        raise EvidenceError("required_rule_failed", "a receipt requires rule evidence")
    disposition = "passed" if all(rule.ok for rule in rules) else "blocked"
    bindings = {
        "repository": dict(envelope.repository),
        "workflow": {
            "run_id": envelope.workflow["run_id"],
            "candidate_id": envelope.workflow["candidate_id"],
            "authorization_hash": envelope.workflow["authorization_hash"],
        },
        "source": {
            "spec_path": envelope.source["spec_path"],
            "spec_hash": envelope.source["spec_hash"],
            "plan_path": envelope.source["plan_path"],
            "plan_hash": envelope.source["plan_hash"],
        },
        "target": dict(envelope.target),
        "prior_event_hash": envelope.prior_event_hash,
    }
    draft = GateReceipt(
        schema_version=1,
        gate=envelope.gate,
        validator_id=validator_id,
        envelope_hash=envelope.envelope_hash,
        bindings=bindings,
        observations=dict(observations),
        rules=tuple(rules),
        disposition=disposition,
        receipt_hash=HashRef("sha256:" + "0" * 64),
    )
    return GateReceipt(**{**draft.__dict__, "receipt_hash": _receipt_hash(draft)})


def parse_receipt(value: Mapping[str, object]) -> GateReceipt:
    if not isinstance(value, Mapping):
        raise EvidenceError("legacy_evidence_unsupported", "receipt must be an object")
    if set(value) == {"ok"} or ("ok" in value and "schema_version" not in value):
        raise EvidenceError("legacy_evidence_unsupported", "legacy receipt shape is unsupported")
    expected = {"schema_version", "gate", "validator_id", "envelope_hash", "bindings", "observations", "rules", "disposition", "receipt_hash"}
    if set(value) != expected:
        raise EvidenceError("schema_invalid", "receipt keys are invalid")
    if value["schema_version"] != 1 or not isinstance(value["schema_version"], int):
        raise EvidenceError("schema_invalid", "unsupported receipt version")
    fields = ("gate", "validator_id", "disposition")
    for field in fields:
        if not isinstance(value[field], str) or not value[field]:
            raise EvidenceError("schema_invalid", f"receipt.{field} must be a string")
    if not is_hash_ref(value["envelope_hash"]) or not is_hash_ref(value["receipt_hash"]):
        raise EvidenceError("schema_invalid", "receipt hashes must be HashRefs")
    if not isinstance(value["bindings"], Mapping) or not isinstance(value["observations"], Mapping):
        raise EvidenceError("schema_invalid", "receipt bindings and observations must be objects")
    if not isinstance(value["rules"], list) or not value["rules"]:
        raise EvidenceError("schema_invalid", "receipt rules must be a non-empty array")
    rules: list[RuleResult] = []
    for item in value["rules"]:
        if not isinstance(item, Mapping) or set(item) != {"rule_id", "ok", "reason"}:
            raise EvidenceError("schema_invalid", "receipt rule shape is invalid")
        if not isinstance(item["rule_id"], str) or not isinstance(item["ok"], bool) or not isinstance(item["reason"], str):
            raise EvidenceError("schema_invalid", "receipt rule types are invalid")
        rules.append(RuleResult(item["rule_id"], item["ok"], item["reason"]))
    return GateReceipt(
        schema_version=1,
        gate=value["gate"],
        validator_id=value["validator_id"],
        envelope_hash=HashRef(value["envelope_hash"]),
        bindings=value["bindings"],
        observations=value["observations"],
        rules=tuple(rules),
        disposition=value["disposition"],
        receipt_hash=HashRef(value["receipt_hash"]),
    )


def verify_receipt(receipt: GateReceipt | Mapping[str, object], envelope: EvidenceEnvelope, expected_gate: str) -> None:
    if isinstance(receipt, Mapping):
        receipt = parse_receipt(receipt)
    if not isinstance(receipt, GateReceipt):
        raise EvidenceError("legacy_evidence_unsupported", "unsupported receipt object")
    if receipt.schema_version != 1 or receipt.gate != expected_gate:
        raise EvidenceError("receipt_stale", "receipt gate or version does not match")
    if receipt.envelope_hash != envelope.envelope_hash:
        raise EvidenceError("receipt_stale", "receipt envelope hash does not match")
    if not is_hash_ref(receipt.receipt_hash) or _receipt_hash(receipt) != receipt.receipt_hash:
        raise EvidenceError("schema_invalid", "receipt_hash mismatch")
    expected_bindings = build_receipt(envelope, receipt.validator_id, receipt.observations, list(receipt.rules)).bindings
    if canonical_json(receipt.bindings) != canonical_json(expected_bindings):
        raise EvidenceError("receipt_stale", "receipt bindings do not match current envelope")
    if receipt.disposition != "passed" or not receipt.rules or not all(rule.ok for rule in receipt.rules):
        raise EvidenceError("required_rule_failed", "receipt is not a passing receipt")
