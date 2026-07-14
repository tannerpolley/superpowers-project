"""Canonical hash-bound gate receipts and receipt consumers."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, HashRef, RuleResult, canonical_json, hash_ref, is_hash_ref
except ImportError:  # pragma: no cover - CLI top-level import fallback
    from evidence_schema import EvidenceEnvelope, EvidenceError, HashRef, RuleResult, canonical_json, hash_ref, is_hash_ref


EXPECTED_VALIDATORS = {
    "pr_ready": "pr-ready-validator@1",
    "premerge": "premerge-validator@1",
    "merge_decision": "merge-decision-validator@1",
    "closeout": "closeout-validator@1",
    "publish_ready": "publish-ready-validator@1",
}

REQUIRED_RECEIPT_RULES = {
    "pr_ready": frozenset({
        "repository_identity", "target_identity", "event_chain", "workflow_binding",
        "target_state", "authorization_binding", "source_artifacts",
        "implementation_verification", "review_disposition", "plan_conformance",
        "workspace_receipt", "cleanup_state",
    }),
    "premerge": frozenset({"repository_identity", "event_chain", "workflow_binding", "target_state", "authorization_binding", "merge_strategy", "source_artifacts", "implementation_verification", "review_disposition", "plan_conformance", "provider_state", "provider_observation", "pr_identity", "required_checks", "base_identity", "head_identity", "mergeability", "provider_reviews"}),
    "merge_decision": frozenset({"repository_identity", "event_chain", "workflow_binding", "target_state", "authorization_binding", "merge_strategy", "source_artifacts", "implementation_verification", "provider_state", "provider_observation", "pr_identity", "required_checks", "base_identity", "head_identity", "mergeability", "provider_reviews"}),
    "closeout": frozenset({"repository_identity", "target_identity", "event_chain", "workflow_binding", "target_state", "authorization_binding", "source_artifacts", "implementation_verification", "integration_proof", "completion_state", "workspace_disposition", "cleanup_state"}),
    "publish_ready": frozenset({"repository_identity", "target_identity", "workflow_binding", "target_state", "authorization_binding", "source_artifacts", "implementation_verification", "source_validation", "sync_validation", "package_provenance", "installation_state", "agent_trial", "publish_authorization", "package_observation_current", "installation_observation_current", "agent_trial_observation_current", "cleanup_state"}),
}


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
    if value["schema_version"] != 1 or isinstance(value["schema_version"], bool) or not isinstance(value["schema_version"], int):
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


def verify_receipt(receipt: GateReceipt | Mapping[str, object], envelope: EvidenceEnvelope, expected_gate: str, *, allow_transition: bool = False) -> None:
    if isinstance(receipt, Mapping):
        receipt = parse_receipt(receipt)
    if not isinstance(receipt, GateReceipt):
        raise EvidenceError("legacy_evidence_unsupported", "unsupported receipt object")
    if receipt.schema_version != 1 or receipt.gate != expected_gate:
        raise EvidenceError("receipt_stale", "receipt gate or version does not match")
    expected_validator = EXPECTED_VALIDATORS.get(expected_gate)
    if expected_validator is None or receipt.validator_id != expected_validator:
        raise EvidenceError("receipt_stale", "receipt validator identity does not match gate")
    if not allow_transition and receipt.envelope_hash != envelope.envelope_hash:
        raise EvidenceError("receipt_stale", "receipt envelope hash does not match")
    if not is_hash_ref(receipt.receipt_hash) or _receipt_hash(receipt) != receipt.receipt_hash:
        raise EvidenceError("schema_invalid", "receipt_hash mismatch")
    expected_bindings = build_receipt(envelope, receipt.validator_id, receipt.observations, list(receipt.rules)).bindings
    if allow_transition:
        for key in ("repository", "workflow", "source", "target"):
            if canonical_json(receipt.bindings.get(key)) != canonical_json(expected_bindings.get(key)):
                rule = {"repository": "repository_identity", "workflow": "workflow_binding", "source": "source_artifacts", "target": "target_identity"}[key]
                raise EvidenceError("receipt_stale", f"receipt {key} binding does not match transition envelope", rule)
        if envelope.prior_event_hash != receipt.receipt_hash:
            raise EvidenceError("receipt_stale", "transition envelope does not name the consumed receipt", "event_chain")
    elif canonical_json(receipt.bindings) != canonical_json(expected_bindings):
        raise EvidenceError("receipt_stale", "receipt bindings do not match current envelope")
    if receipt.disposition != "passed" or not receipt.rules or not all(rule.ok for rule in receipt.rules):
        raise EvidenceError("required_rule_failed", "receipt is not a passing receipt")
    required_rules = REQUIRED_RECEIPT_RULES.get(expected_gate, frozenset())
    observed_rules = {rule.rule_id for rule in receipt.rules}
    missing_rules = sorted(required_rules - observed_rules)
    if missing_rules:
        raise EvidenceError("required_rule_failed", "receipt omits required rules: " + ", ".join(missing_rules))


def verify_receipt_hash(receipt: GateReceipt | Mapping[str, object]) -> GateReceipt:
    """Authenticate a receipt when its consuming boundary has no envelope."""
    parsed = parse_receipt(receipt) if isinstance(receipt, Mapping) else receipt
    if not isinstance(parsed, GateReceipt) or not is_hash_ref(parsed.receipt_hash) or _receipt_hash(parsed) != parsed.receipt_hash:
        raise EvidenceError("schema_invalid", "receipt_hash mismatch")
    return parsed


def verify_transition_receipt(receipt: GateReceipt | Mapping[str, object], envelope: EvidenceEnvelope, expected_gate: str) -> GateReceipt:
    """Authenticate the immediately preceding gate across an allowed target transition."""
    parsed = parse_receipt(receipt) if isinstance(receipt, Mapping) else receipt
    if not isinstance(parsed, GateReceipt):
        raise EvidenceError("legacy_evidence_unsupported", "unsupported receipt object")
    if parsed.gate != expected_gate or parsed.validator_id != EXPECTED_VALIDATORS.get(expected_gate):
        raise EvidenceError("receipt_stale", "prior gate or validator does not match transition")
    if not is_hash_ref(parsed.receipt_hash) or _receipt_hash(parsed) != parsed.receipt_hash:
        raise EvidenceError("schema_invalid", "receipt_hash mismatch")
    if parsed.disposition != "passed" or not parsed.rules or not all(rule.ok for rule in parsed.rules):
        raise EvidenceError("required_rule_failed", "prior receipt is not passing")
    missing = sorted(REQUIRED_RECEIPT_RULES.get(expected_gate, frozenset()) - {rule.rule_id for rule in parsed.rules})
    if missing:
        raise EvidenceError("required_rule_failed", "prior receipt omits required rules: " + ", ".join(missing))
    if envelope.prior_event_hash != parsed.receipt_hash:
        raise EvidenceError("receipt_stale", "transition does not name the immediately preceding receipt", "event_chain")
    expected = build_receipt(envelope, parsed.validator_id, parsed.observations, list(parsed.rules)).bindings
    for key in ("repository", "workflow", "source"):
        if canonical_json(parsed.bindings.get(key)) != canonical_json(expected.get(key)):
            rule = {"repository": "repository_identity", "workflow": "workflow_binding", "source": "source_artifacts"}[key]
            raise EvidenceError("receipt_stale", f"prior {key} binding does not match transition", rule)
    prior_target = parsed.bindings.get("target")
    next_target = expected.get("target")
    stable_target_keys = {"task_id", "workspace_id", "isolation_required", "workspace_provider", "workspace_thread_id", "workspace_owner", "cleanup_actor"}
    if not isinstance(prior_target, Mapping) or not isinstance(next_target, Mapping):
        raise EvidenceError("receipt_stale", "transition target binding is missing")
    for key in stable_target_keys & (set(prior_target) | set(next_target)):
        if prior_target.get(key) != next_target.get(key):
            raise EvidenceError("receipt_stale", f"transition target {key} changed", "target_identity")
    return parsed
