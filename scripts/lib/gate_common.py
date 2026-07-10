"""Shared deterministic rule evaluation for execution gates."""
from __future__ import annotations

from collections.abc import Callable

from .evidence_schema import EvidenceError, EvidenceEnvelope, RuleResult


def evaluate_rules(checks: list[tuple[str, Callable[[], tuple[bool, str]]]]) -> list[RuleResult]:
    return [RuleResult(rule_id=name, ok=ok, reason=reason) for name, check in checks for ok, reason in [check()]]


def require_gate(envelope: EvidenceEnvelope, gate: str) -> None:
    if envelope.gate != gate:
        raise EvidenceError("schema_invalid", f"envelope gate must be {gate}")


def require_all_rules(rules: list[RuleResult]) -> None:
    failures = [rule for rule in rules if not rule.ok]
    if failures:
        first = failures[0]
        raise EvidenceError("required_rule_failed", first.reason, first.rule_id)


def evidence_by_kind(envelope: EvidenceEnvelope) -> dict[str, list[object]]:
    result: dict[str, list[object]] = {}
    for item in envelope.evidence:
        result.setdefault(item.kind, []).append(item.payload)
    return result
