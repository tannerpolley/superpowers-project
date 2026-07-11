"""Shared deterministic rule evaluation for execution gates."""
from __future__ import annotations

from collections.abc import Callable
import subprocess
from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceError, EvidenceEnvelope, RuleResult
except ImportError:  # pragma: no cover - CLI top-level import fallback
    from evidence_schema import EvidenceError, EvidenceEnvelope, RuleResult


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


def current_git_state(repo_root: Path) -> dict[str, str | int]:
    def read(argv: list[str]) -> tuple[int, str]:
        result = subprocess.run(argv, cwd=repo_root, stdin=subprocess.DEVNULL, text=True, capture_output=True, check=False, timeout=10)
        return result.returncode, result.stdout.strip()

    status_code, status = read(["git", "status", "--short"])
    _, head = read(["git", "rev-parse", "HEAD"])
    _, branch = read(["git", "branch", "--show-current"])
    _, common = read(["git", "rev-parse", "--git-common-dir"])
    common_path = Path(common)
    if not common_path.is_absolute():
        common_path = repo_root / common_path
    return {
        "status_exit_code": status_code,
        "dirty": bool(status),
        "head": head,
        "branch": branch,
        "git_common_dir": str(common_path.resolve()),
    }


def require_evidence(envelope: EvidenceEnvelope, required: set[str]) -> dict[str, list[object]]:
    if not envelope.evidence:
        raise EvidenceError("evidence_missing", "evidence array is empty")
    grouped = evidence_by_kind(envelope)
    missing = sorted(required - set(grouped))
    if missing:
        raise EvidenceError("required_rule_failed", "missing evidence: " + ", ".join(missing), "evidence_kinds")
    for item in envelope.evidence:
        if "ok" in item.payload:
            raise EvidenceError("collector_untrusted", "collector payload contains a forged success boolean", "collector_trust")
    return grouped


def identity_rules(envelope: EvidenceEnvelope, repo_root: Path) -> list[RuleResult]:
    current = current_git_state(repo_root)
    return evaluate_rules([
        ("repository_identity", lambda: (
            str(Path(str(envelope.repository["root"])).resolve()) == str(repo_root.resolve())
            and str(Path(str(envelope.repository["git_common_dir"])).resolve()) == str(current["git_common_dir"]),
            "repository identity matches active checkout" if str(Path(str(envelope.repository["root"])).resolve()) == str(repo_root.resolve()) and str(Path(str(envelope.repository["git_common_dir"])).resolve()) == str(current["git_common_dir"]) else "repository identity changed",
        )),
        ("target_identity", lambda: (
            str(envelope.target["branch"]) == str(current["branch"]),
            "target branch matches active checkout" if str(envelope.target["branch"]) == str(current["branch"]) else "target branch changed",
        )),
    ])


def git_state_rule(grouped: Mapping[str, list[object]], repo_root: Path) -> RuleResult:
    payload = grouped.get("git_state", [None])[0]
    current = current_git_state(repo_root)
    ok = isinstance(payload, Mapping) and payload.get("status_exit_code") == 0 and payload.get("head") == current["head"] and payload.get("branch", "detached-head") == (current["branch"] or "detached-head") and payload.get("git_common_dir") == current["git_common_dir"]
    return RuleResult("target_state", ok, "observed Git state matches current checkout" if ok else "observed Git state is stale or unavailable")


def workflow_binding_rule(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope) -> RuleResult:
    expected_run = envelope.workflow["run_id"]
    expected_candidate = envelope.workflow["candidate_id"]
    for payloads in grouped.values():
        for payload in payloads:
            if not isinstance(payload, Mapping):
                continue
            if "run_id" in payload and payload["run_id"] != expected_run:
                return RuleResult("workflow_binding", False, "evidence run_id does not match envelope")
            if "candidate_id" in payload and payload["candidate_id"] != expected_candidate:
                return RuleResult("workflow_binding", False, "evidence candidate_id does not match envelope")
    return RuleResult("workflow_binding", True, "evidence workflow identity matches envelope")


def authorization_rule(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope) -> RuleResult:
    payload = grouped.get("authorization_event", [None])[0]
    actual = payload.get("event_hash") if isinstance(payload, Mapping) else None
    return RuleResult("authorization_binding", actual == envelope.workflow["authorization_hash"], "authorization matches workflow" if actual == envelope.workflow["authorization_hash"] else "authorization does not match workflow")


def source_artifact_rule(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope) -> RuleResult:
    payload = grouped.get("artifact_hashes", [None])[0]
    paths = payload.get("paths", {}) if isinstance(payload, Mapping) else {}
    expected = envelope.source["plan_hash"]
    actual = paths.get(envelope.source["plan_path"]) if isinstance(paths, Mapping) else None
    ok = actual == expected
    return RuleResult("source_artifacts", ok, "source artifacts match" if ok else "source artifact hash is stale")


def command_rule(grouped: Mapping[str, list[object]]) -> RuleResult:
    payloads = grouped.get("command_result", [])
    ok = bool(payloads) and all(isinstance(payload, Mapping) and payload.get("exit_code") == 0 and payload.get("timed_out") is False for payload in payloads)
    return RuleResult("implementation_verification", ok, "all observed commands passed" if ok else "a required command failed or was incomplete")


def review_rules(grouped: Mapping[str, list[object]]) -> tuple[RuleResult, RuleResult]:
    payload = grouped.get("review_result", [None])[0]
    reviews = payload.get("reviews", []) if isinstance(payload, Mapping) else []
    approved = isinstance(reviews, list) and any(isinstance(review, Mapping) and review.get("approved") is True for review in reviews)
    blocking = isinstance(reviews, list) and any(isinstance(review, Mapping) and review.get("blocking") is True for review in reviews)
    disposition = approved and not blocking
    conformance = isinstance(reviews, list) and any(isinstance(review, Mapping) and review.get("plan_conformance") is True for review in reviews)
    return (
        RuleResult("review_disposition", disposition, "review disposition is approved" if disposition else "review is missing approval or has a blocker"),
        RuleResult("plan_conformance", conformance, "source plan conformance is observed" if conformance else "source plan conformance is missing"),
    )


def cleanup_rule(grouped: Mapping[str, list[object]]) -> RuleResult:
    payload = grouped.get("cleanup_state", [None])[0]
    ok = isinstance(payload, Mapping) and payload.get("status_exit_code") == 0 and payload.get("dirty", False) is False and payload.get("task_owned_paths", []) == []
    return RuleResult("cleanup_state", ok, "cleanup state is clean" if ok else "cleanup state is incomplete or dirty")


def workspace_rule(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope) -> RuleResult:
    if not envelope.target.get("isolation_required", False):
        return RuleResult("workspace_receipt", True, "workspace receipt not required")
    payload = grouped.get("workspace_receipt", [None])[0]
    ok = isinstance(payload, Mapping) and payload.get("workspace_id") == envelope.target["workspace_id"]
    return RuleResult("workspace_receipt", ok, "workspace receipt matches target" if ok else "workspace receipt is missing or mismatched")
