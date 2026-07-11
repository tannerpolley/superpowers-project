"""Fail-closed release readiness validation from current package evidence."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, hash_ref, is_hash_ref
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule, cleanup_rule
    from .gate_receipts import build_receipt
    from .package_provenance import runtime_contract_hash, runtime_manifest
except ImportError:  # pragma: no cover
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, hash_ref, is_hash_ref
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule, cleanup_rule
    from gate_receipts import build_receipt
    from package_provenance import runtime_contract_hash, runtime_manifest


PUBLISH_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "package_provenance", "installation_state", "agent_trial", "cleanup_state", "authorization_event"}


def _current_package(root: Path) -> tuple[str, str, str]:
    manifest = json.loads((root / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
    package_hash = hash_ref([entry.to_dict() for entry in runtime_manifest(root)])
    return package_hash, str(manifest.get("version", "")), runtime_contract_hash(root)


def _release_rules(grouped: Mapping[str, list[object]], root: Path, current_head: str) -> list[RuleResult]:
    package_hash, version, contract_hash = _current_package(root)
    package = grouped.get("package_provenance", [None])[0]
    installation = grouped.get("installation_state", [None])[0]
    trial = grouped.get("agent_trial", [None])[0]
    package_ok = isinstance(package, Mapping) and package.get("package_hash") == package_hash and package.get("commit") == current_head and package.get("manifest_version") == version and package.get("contract_hash") == contract_hash and package.get("revision_classification") in {"runtime", "docs-only"}
    install_ok = isinstance(installation, Mapping) and installation.get("package_hash") == package_hash and installation.get("commit") == current_head and installation.get("manifest_version") == version and installation.get("source") == "current"
    receipt_hashes = trial.get("receipt_hashes") if isinstance(trial, Mapping) else None
    trial_ok = isinstance(trial, Mapping) and trial.get("package_hash") == package_hash and isinstance(trial.get("tool_calls"), list) and bool(trial.get("tool_calls")) and trial.get("external_mutations") == 0 and isinstance(receipt_hashes, list) and bool(receipt_hashes) and all(is_hash_ref(item) for item in receipt_hashes)
    return [
        RuleResult("package_provenance", package_ok, "runtime package provenance matches current source" if package_ok else "runtime package provenance is stale or incomplete"),
        RuleResult("installation_state", install_ok, "installation matches current source package" if install_ok else "installation proof is stale or incomplete"),
        RuleResult("agent_trial", trial_ok, "agent trial contains observed calls and receipts" if trial_ok else "agent trial proof is stale, incomplete, or reports external mutation"),
    ]


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
        *_release_rules(grouped, root, str(current["head"])),
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
        },
        rules,
    )
