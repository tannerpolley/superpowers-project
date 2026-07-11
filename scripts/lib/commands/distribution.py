"""Release preparation command handlers."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

try:
    from ..agent_usability import validate_trial_set
    from ..command_support import Context, arg_value, emit, has_switch, project_path_for, project_root_for, read_json_arg, read_text, resolve_under, run, write_text
    from ..evidence_collectors import CollectionRequest, build_evidence_envelope
    from ..evidence_schema import EvidenceError, hash_bytes_ref, hash_ref
    from ..gate_receipts import EXPECTED_VALIDATORS, verify_receipt_hash
    from ..package_provenance import runtime_contract_hash, runtime_manifest
    from ..release_evidence import base_release_tag, validate_dependency_pins
except ImportError:
    from agent_usability import validate_trial_set
    from command_support import Context, arg_value, emit, has_switch, project_path_for, project_root_for, read_json_arg, read_text, resolve_under, run, write_text
    from evidence_collectors import CollectionRequest, build_evidence_envelope
    from evidence_schema import EvidenceError, hash_bytes_ref, hash_ref
    from gate_receipts import EXPECTED_VALIDATORS, verify_receipt_hash
    from package_provenance import runtime_contract_hash, runtime_manifest
    from release_evidence import base_release_tag, validate_dependency_pins


def _package_hash(root):
    return hash_ref([entry.to_dict() for entry in runtime_manifest(root)])


def _collect_publish_ready(root: Path, args: dict[str, Any]) -> int:
    authorization, _ = read_json_arg(root, args, "AuthorizationJson", "AuthorizationPath", required=False)
    if not isinstance(authorization, dict) or authorization.get("authorized") is not True:
        raise EvidenceError("evidence_missing", "an approved AuthorizationJson or AuthorizationPath is required")
    head = run(["git", "rev-parse", "HEAD"], root)
    branch = run(["git", "branch", "--show-current"], root)
    if head.returncode != 0 or branch.returncode != 0 or not head.stdout.strip() or not branch.stdout.strip():
        raise EvidenceError("evidence_missing", "current Git identity is required for publish-ready collection")
    package = _package_hash(root)
    manifest = json.loads(read_text(root / ".codex-plugin" / "plugin.json"))
    live_value = arg_value(args, "LivePluginRoot", default=str(Path.home() / ".codex" / "plugins" / "superpowers-project"))
    live_root = Path(str(live_value)).expanduser().resolve()
    try:
        installed_package = _package_hash(live_root)
        installed_contract = runtime_contract_hash(live_root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise EvidenceError("evidence_missing", "current installed plugin provenance is required") from exc

    receipt_dir_value = arg_value(args, "AgentReceiptDir", default="tests/workflow-trials/receipts/current")
    receipt_dir = project_path_for(root, str(receipt_dir_value), "AgentReceiptDir")
    receipt_paths = sorted(receipt_dir.glob("**/receipt.json")) if receipt_dir.is_dir() else []
    if not receipt_paths:
        raise EvidenceError("evidence_missing", "agent trial receipts are required")
    try:
        receipts = [json.loads(path.read_text(encoding="utf-8")) for path in receipt_paths]
        trial_metrics = validate_trial_set(receipts, root)
    except Exception as exc:
        raise EvidenceError("required_rule_failed", f"agent trial receipts are invalid: {exc}", "agent_trial") from exc
    tool_calls: list[dict[str, object]] = []
    external_mutations = 0
    for path, receipt in zip(receipt_paths, receipts):
        ledger = receipt.get("event_ledger", {}) if isinstance(receipt, dict) else {}
        project_value = receipt.get("project_root") if isinstance(receipt, dict) else None
        project_root = Path(str(project_value)) if isinstance(project_value, str) else root
        if not project_root.is_absolute():
            project_root = root / project_root
        ledger_value = ledger.get("path") if isinstance(ledger, dict) else None
        ledger_path = Path(str(ledger_value)) if isinstance(ledger_value, str) else Path("missing")
        if not ledger_path.is_absolute():
            ledger_path = project_root / ledger_path
        events = []
        if ledger_path.is_file():
            events = [json.loads(line) for line in ledger_path.read_text(encoding="utf-8").splitlines() if line.strip()]
        tool_calls.extend({"receipt": path.relative_to(root).as_posix(), "type": event.get("type"), "hash": event.get("hash")} for event in events if isinstance(event, dict))
        external_mutations += int(receipt.get("external_mutations", 0))
    source = {
        "spec_path": arg_value(args, "SpecPath", default="docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md"),
        "plan_path": arg_value(args, "PlanPath", default="docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md"),
    }
    run_id = str(arg_value(args, "RunId", default=f"publish-ready-{head.stdout.strip()[:12]}"))
    candidate_id = str(arg_value(args, "CandidateId", default="source"))
    workflow = {
        "run_id": run_id,
        "candidate_id": candidate_id,
        "mode": str(arg_value(args, "Mode", default="manual")),
        "authorization_hash": hash_ref(authorization),
    }
    provider_inputs = {
        "authorization": authorization,
        "package": {
            "package_hash": package,
            "contract_hash": runtime_contract_hash(root),
            "manifest_version": manifest.get("version"),
            "commit": head.stdout.strip(),
            "revision_classification": str(arg_value(args, "RevisionClassification", default="runtime")),
        },
        "installation": {
            "package_hash": package,
            "manifest_version": manifest.get("version"),
            "commit": head.stdout.strip(),
            "source": "current" if installed_package == package and installed_contract == runtime_contract_hash(root) else "stale",
            "installed_root": str(live_root),
            "installed_package_hash": installed_package,
            "installed_contract_hash": installed_contract,
        },
        "agent_trial": {
            "package_hash": package,
            "tool_calls": tool_calls,
            "external_mutations": external_mutations,
            "receipt_hashes": [hash_bytes_ref(path.read_bytes()) for path in receipt_paths],
            "metrics": trial_metrics,
        },
    }
    request = CollectionRequest(
        gate="publish_ready",
        repository_root=root,
        workflow=workflow,
        source=source,
        target={"task_id": "issue-113", "workspace_id": "local", "branch": branch.stdout.strip(), "isolation_required": False},
        commands=("unit_command_registry", "runtime_package_validation"),
        provider_inputs=provider_inputs,
    )
    envelope = build_evidence_envelope(request)
    output_value = arg_value(args, "OutputPath")
    output_rel = ""
    if output_value:
        output = project_path_for(root, str(output_value), "OutputPath")
        write_text(output, json.dumps(envelope, indent=2, ensure_ascii=False) + "\n")
        output_rel = str(output.relative_to(root))
    return emit({"ok": True, "phase": "collect-publish-ready", "evidence_envelope": envelope, "output_path": output_rel})


def _error(phase: str, error: EvidenceError) -> int:
    payload: dict[str, object] = {
        "ok": False,
        "phase": phase,
        "error": {"code": error.code, "message": error.message},
    }
    if error.rule is not None:
        payload["error"]["rule"] = error.rule  # type: ignore[index]
    return emit(payload, 1)


def _load_publish_receipt(root, args):
    data, _ = read_json_arg(root, args, "PublishReadyReceiptJson", "PublishReadyReceiptPath", required=False)
    if data is None:
        raise EvidenceError("evidence_missing", "PublishReadyReceiptJson or PublishReadyReceiptPath is required")
    receipt = verify_receipt_hash(data)
    if receipt.gate != "publish_ready" or receipt.validator_id != EXPECTED_VALIDATORS["publish_ready"] or receipt.disposition != "passed":
        raise EvidenceError("receipt_stale", "a passing publish-ready receipt is required")
    bindings = receipt.bindings
    repository = bindings.get("repository") if isinstance(bindings, dict) else None
    source = bindings.get("source") if isinstance(bindings, dict) else None
    target = bindings.get("target") if isinstance(bindings, dict) else None
    root_value = str(Path(str(repository.get("root"))).resolve()) if isinstance(repository, dict) else ""
    if root_value != str(root.resolve()):
        raise EvidenceError("repository_mismatch", "publish-ready receipt repository does not match invocation")
    current = run(["git", "rev-parse", "HEAD"], root)
    branch = run(["git", "branch", "--show-current"], root)
    status = run(["git", "status", "--short"], root)
    if current.returncode != 0 or receipt.observations.get("head") != current.stdout.strip() or receipt.observations.get("branch") != branch.stdout.strip() or status.stdout.strip():
        raise EvidenceError("receipt_stale", "publish-ready receipt no longer matches current Git state")
    if not isinstance(source, dict) or not isinstance(target, dict):
        raise EvidenceError("receipt_stale", "publish-ready receipt bindings are incomplete")
    plan_path = source.get("plan_path")
    try:
        plan_file = resolve_under(root, str(plan_path), "publish-ready source plan")
    except Exception as exc:
        raise EvidenceError("repository_mismatch", "publish-ready source plan is outside the repository") from exc
    if not isinstance(plan_path, str) or not plan_file.is_file() or hash_bytes_ref(plan_file.read_bytes()) != source.get("plan_hash"):
        raise EvidenceError("artifact_hash_mismatch", "publish-ready receipt plan hash is stale")
    expected_branch = target.get("branch") if isinstance(target, dict) else None
    if expected_branch != branch.stdout.strip():
        raise EvidenceError("receipt_stale", "publish-ready receipt target branch is stale")
    manifest = json.loads(read_text(root / ".codex-plugin" / "plugin.json"))
    if receipt.observations.get("package_hash") != _package_hash(root) or receipt.observations.get("manifest_version") != manifest.get("version") or receipt.observations.get("contract_hash") != runtime_contract_hash(root):
        raise EvidenceError("receipt_stale", "publish-ready package identity is stale")
    return receipt


def _command_prepare_release(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    if has_switch(args, "CollectOnly"):
        return _collect_publish_ready(root, args)
    manifest = json.loads(read_text(root / ".codex-plugin" / "plugin.json"))
    version = str(arg_value(args, "Version", default=manifest.get("version", ""))).lstrip("v")
    base = version.split("+", 1)[0]
    changelog = read_text(root / "CHANGELOG.md")
    has_unreleased = bool(re.search(r"(?m)^##\s+Unreleased\s*$", changelog))
    has_version = bool(re.search(rf"(?m)^##\s+v?{re.escape(base)}(\s|$)", changelog))
    head = run(["git", "rev-parse", "HEAD"], root)
    status = run(["git", "status", "--short"], root)
    branch = run(["git", "branch", "--show-current"], root)
    dirty = bool(status.stdout.strip())
    check_only = has_switch(args, "CheckOnly")
    pin_findings = validate_dependency_pins(root / "requirements-validation.txt")
    checks = [
        {"name": "manifest name", "ok": manifest.get("name") == "superpowers-project", "reason": "passed" if manifest.get("name") == "superpowers-project" else "manifest name must be superpowers-project"},
        {"name": "manifest version present", "ok": bool(manifest.get("version")), "reason": "passed" if manifest.get("version") else "manifest version is empty"},
        {"name": "changelog has release evidence", "ok": has_unreleased or has_version, "reason": "passed" if has_unreleased or has_version else f"CHANGELOG.md needs Unreleased or {base} entry"},
        {"name": "git head available", "ok": head.returncode == 0, "reason": "passed" if head.returncode == 0 else head.stderr.strip()},
        {"name": "validation dependencies pinned", "ok": not pin_findings, "reason": "passed" if not pin_findings else "; ".join(pin_findings)},
    ]
    package_hash = runtime_contract_hash(root)
    release_evidence = None
    publish_receipt = None
    trial_metrics = None
    if not check_only:
        checks.extend([
            {"name": "worktree clean", "ok": not dirty, "reason": "passed" if not dirty else "release publishing requires a clean worktree"},
            {"name": "version entry exists", "ok": has_version, "reason": "passed" if has_version else "release publishing requires a versioned changelog entry"},
        ])
        if arg_value(args, "ReleaseEvidenceJson", "ReleaseEvidencePath") is not None:
            raise EvidenceError("legacy_evidence_unsupported", "release preparation consumes PublishReadyReceiptJson or PublishReadyReceiptPath")
        publish_receipt = _load_publish_receipt(root, args)
        checks.append({"name": "publish-ready receipt current", "ok": True, "reason": "passed"})
    ok = all(item["ok"] for item in checks)
    receipt = {
        "ok": ok, "phase": "prepare-release", "check_only": check_only,
        "manifest_name": manifest.get("name", ""), "manifest_version": manifest.get("version", ""),
        "release_version": version, "release_base_version": base, "release_tag": base_release_tag(version),
        "package_hash": package_hash, "branch": branch.stdout.strip(), "commit": head.stdout.strip() if head.returncode == 0 else "",
        "dirty": dirty, "dirty_status": status.stdout.strip(),
        "changelog": {"has_unreleased": has_unreleased, "has_version_entry": has_version, "path": "CHANGELOG.md"},
        "required_gates": ["scripts/validate.sh", "scripts/sync-live.sh --validate", "git status --short"],
        "publish_ready": bool(not check_only and publish_receipt is not None and ok), "publish_ready_receipt_hash": publish_receipt.receipt_hash if publish_receipt else None, "agent_trial_metrics": trial_metrics,
        "release_evidence": release_evidence, "checks": checks,
    }
    output = arg_value(args, "OutputPath")
    if output:
        write_text(resolve_under(root, str(output), "OutputPath"), json.dumps(receipt, indent=2))
    return emit(receipt, 0 if ok else 1)


def command_prepare_release(ctx: Context, args: dict[str, Any]) -> int:
    try:
        return _command_prepare_release(ctx, args)
    except EvidenceError as exc:
        return _error("prepare-release", exc)
    except Exception as exc:
        return _error("prepare-release", EvidenceError("schema_invalid", str(exc)))


HANDLERS = {"command_prepare_release": command_prepare_release}
