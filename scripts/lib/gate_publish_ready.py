"""Fail-closed release readiness validation from current package evidence."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Mapping

try:
    from .evidence_collectors import collect_agent_trial, collect_installation_state, collect_package_provenance
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, hash_ref, is_hash_ref
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule, cleanup_rule
    from .gate_receipts import build_receipt
    from .package_provenance import runtime_contract_hash, runtime_manifest
except ImportError:  # pragma: no cover
    from evidence_collectors import collect_agent_trial, collect_installation_state, collect_package_provenance
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, hash_ref, is_hash_ref
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule, cleanup_rule
    from gate_receipts import build_receipt
    from package_provenance import runtime_contract_hash, runtime_manifest


PUBLISH_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "package_provenance", "installation_state", "agent_trial", "cleanup_state", "authorization_event"}


def _current_package(root: Path) -> tuple[str, str, str]:
    manifest = json.loads((root / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    package_hash = hash_ref([entry.to_dict() for entry in runtime_manifest(root)])
    return package_hash, str(manifest.get("version", "")), runtime_contract_hash(root)


def _release_rules(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope, root: Path, current_head: str) -> list[RuleResult]:
    package_hash, version, contract_hash = _current_package(root)
    package = grouped.get("package_provenance", [None])[0]
    installation = grouped.get("installation_state", [None])[0]
    trial = grouped.get("agent_trial", [None])[0]
    package_ok = isinstance(package, Mapping) and package.get("observation_id") == "package_current" and package.get("package_hash") == package_hash and package.get("commit") == current_head and package.get("manifest_version") == version and package.get("contract_hash") == contract_hash and package.get("revision_classification") in {"runtime", "docs-only"} and isinstance(package.get("modes"), Mapping)
    installation_root = str(Path(str(envelope.target["installation_root"])).resolve())
    trial_root = str(Path(str(envelope.target["agent_trial_root"])).resolve())
    install_ok = isinstance(installation, Mapping) and installation.get("observation_id") == "installation_current" and installation.get("installed_package_hash") == package_hash and installation.get("installed_contract_hash") == contract_hash and installation.get("manifest_version") == version and installation.get("current_version") == version and installation.get("modes") == package.get("modes") and installation.get("installation_root") == installation_root
    receipt_hashes = trial.get("receipt_hashes") if isinstance(trial, Mapping) else None
    metrics = trial.get("metrics") if isinstance(trial, Mapping) else None
    trial_ok = isinstance(trial, Mapping) and trial.get("observation_id") == "agent_trials_current" and trial.get("receipt_root") == trial_root and trial.get("package_hash") == package_hash and isinstance(trial.get("tool_calls"), list) and bool(trial.get("tool_calls")) and trial.get("external_mutations") == 0 and isinstance(receipt_hashes, list) and bool(receipt_hashes) and all(is_hash_ref(item) for item in receipt_hashes) and isinstance(metrics, Mapping) and metrics.get("external_mutations") == 0 and metrics.get("user_input_calls") == 0
    authorization_payload = grouped.get("authorization_event", [None])[0]
    authorization = authorization_payload.get("event") if isinstance(authorization_payload, Mapping) else None
    authorization_ok = isinstance(authorization, Mapping) and authorization.get("authorized") is True and authorization.get("scope") == "publish_ready" and authorization.get("run_id") == envelope.workflow["run_id"] and authorization.get("candidate_id") == envelope.workflow["candidate_id"] and authorization.get("source_plan_hash") == envelope.source["plan_hash"] and authorization.get("package_hash") == package_hash
    return [
        RuleResult("package_provenance", package_ok, "runtime package provenance matches current source" if package_ok else "runtime package provenance is stale or incomplete"),
        RuleResult("installation_state", install_ok, "installation matches current source package" if install_ok else "installation proof is stale or incomplete"),
        RuleResult("agent_trial", trial_ok, "agent trial contains observed calls and receipts" if trial_ok else "agent trial proof is stale, incomplete, or reports external mutation"),
        RuleResult("publish_authorization", authorization_ok, "publish authorization binds scope, workflow, source, and package" if authorization_ok else "publish authorization is missing required bindings"),
    ]


def _trusted_evidence_observations(grouped: Mapping[str, list[object]]) -> dict[str, object]:
    observations: dict[str, object] = {}
    for kind in ("package_provenance", "installation_state", "agent_trial"):
        payload = grouped.get(kind, [None])[0]
        if isinstance(payload, Mapping):
            observations[kind] = {"payload_hash": hash_ref(payload), "observation_id": payload.get("observation_id")}
            if kind == "installation_state":
                observations[kind]["installation_root"] = payload.get("installation_root")  # type: ignore[index]
            if kind == "agent_trial":
                observations[kind]["receipt_root"] = payload.get("receipt_root")  # type: ignore[index]
    commands: dict[str, object] = {}
    for payload in grouped.get("command_result", []):
        if isinstance(payload, Mapping) and isinstance(payload.get("command_id"), str):
            commands[payload["command_id"]] = hash_ref(payload)
    observations["commands"] = commands
    authorization = grouped.get("authorization_event", [None])[0]
    if isinstance(authorization, Mapping) and isinstance(authorization.get("event"), Mapping):
        observations["authorization"] = dict(authorization["event"])
    return observations


def _fresh_observation_rules(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope, root: Path) -> list[RuleResult]:
    checks: list[tuple[str, str, object]] = [
        ("package_observation_current", "package_provenance", collect_package_provenance),
        ("installation_observation_current", "installation_state", collect_installation_state),
        ("agent_trial_observation_current", "agent_trial", collect_agent_trial),
    ]
    rules: list[RuleResult] = []
    for rule_id, kind, collector in checks:
        payload = grouped.get(kind, [None])[0]
        try:
            if not isinstance(payload, Mapping):
                raise EvidenceError("evidence_missing", f"{kind} observation is missing")
            observation_id = payload.get("observation_id")
            if kind == "installation_state":
                fresh = collector(root, str(observation_id), Path(str(envelope.target["installation_root"])).resolve())
            elif kind == "agent_trial":
                fresh = collector(root, str(observation_id), Path(str(envelope.target["agent_trial_root"])).resolve())
            else:
                fresh = collector(root, str(observation_id))
            ok = hash_ref(fresh.payload) == hash_ref(payload)
            rules.append(RuleResult(rule_id, ok, "trusted observation matches current state" if ok else "trusted observation is stale or forged"))
        except Exception as exc:
            rules.append(RuleResult(rule_id, False, f"trusted observation is unavailable: {exc}"))
    return rules


def _release_command_rules(grouped: Mapping[str, list[object]]) -> list[RuleResult]:
    payloads = grouped.get("command_result", [])
    by_id = {payload.get("command_id"): payload for payload in payloads if isinstance(payload, Mapping)}
    rules = []
    for rule_id, command_id in (("source_validation", "source_validation"), ("sync_validation", "sync_live_validation")):
        payload = by_id.get(command_id)
        ok = isinstance(payload, Mapping) and payload.get("exit_code") == 0 and payload.get("timed_out") is False
        rules.append(RuleResult(rule_id, ok, f"trusted {command_id} completed successfully" if ok else f"trusted {command_id} is missing or failed"))
    return rules


def validate_publish_ready(envelope: EvidenceEnvelope, repo_root: Path):
    if envelope.gate != "publish_ready":
        raise EvidenceError("schema_invalid", "envelope gate must be publish_ready")
    root = Path(repo_root).resolve()
    grouped = require_evidence(envelope, PUBLISH_REQUIRED_KINDS)
    current = current_git_state(root)
    rules = identity_rules(envelope, root)
    rules.extend([
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, root),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *_release_command_rules(grouped),
        *_release_rules(grouped, envelope, root, str(current["head"])),
        *_fresh_observation_rules(grouped, envelope, root),
        cleanup_rule(grouped, root),
    ])
    require_all_rules(rules)
    package_hash, version, contract_hash = _current_package(root)
    return build_receipt(
        envelope,
        "publish-ready-validator@1",
        {
            "head": current["head"],
            "branch": current["branch"],
            "status_exit_code": current["status_exit_code"],
            "package_hash": package_hash,
            "manifest_version": version,
            "contract_hash": contract_hash,
            "trusted_evidence": _trusted_evidence_observations(grouped),
        },
        rules,
    )
