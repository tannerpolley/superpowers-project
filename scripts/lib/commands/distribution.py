"""Release preparation command handlers."""
from __future__ import annotations

import json
import re
from typing import Any

try:
    from ..agent_usability import validate_trial_set
    from ..command_support import Context, arg_value, emit, has_switch, project_path_for, project_root_for, read_text, resolve_under, run, write_text
    from ..package_provenance import runtime_contract_hash
    from ..release_evidence import base_release_tag, validate_dependency_pins, validate_release_evidence
except ImportError:
    from agent_usability import validate_trial_set
    from command_support import Context, arg_value, emit, has_switch, project_path_for, project_root_for, read_text, resolve_under, run, write_text
    from package_provenance import runtime_contract_hash
    from release_evidence import base_release_tag, validate_dependency_pins, validate_release_evidence


def command_prepare_release(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
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
    trial_metrics = None
    if not check_only:
        checks.extend([
            {"name": "worktree clean", "ok": not dirty, "reason": "passed" if not dirty else "release publishing requires a clean worktree"},
            {"name": "version entry exists", "ok": has_version, "reason": "passed" if has_version else "release publishing requires a versioned changelog entry"},
        ])
        evidence_json = arg_value(args, "ReleaseEvidenceJson")
        evidence_path = arg_value(args, "ReleaseEvidencePath")
        if bool(evidence_json) == bool(evidence_path):
            checks.append({"name": "release evidence supplied", "ok": False, "reason": "provide exactly one of ReleaseEvidenceJson or ReleaseEvidencePath"})
        else:
            try:
                release_evidence = json.loads(str(evidence_json)) if evidence_json else json.loads(read_text(project_path_for(root, str(evidence_path), "ReleaseEvidencePath")))
                validate_release_evidence(release_evidence)
                current = release_evidence.get("commit") == head.stdout.strip() and release_evidence.get("package_hash") == package_hash and release_evidence.get("manifest_version") == manifest.get("version")
                checks.append({"name": "release evidence current", "ok": current, "reason": "passed" if current else "release evidence does not match current source"})
            except Exception as exc:
                checks.append({"name": "release evidence current", "ok": False, "reason": str(exc)})
        trial_dir = arg_value(args, "AgentReceiptDir")
        if not trial_dir:
            checks.append({"name": "agent trial receipts", "ok": False, "reason": "AgentReceiptDir is required"})
        else:
            try:
                directory = project_path_for(root, str(trial_dir), "AgentReceiptDir")
                receipts = [json.loads(read_text(path)) for path in sorted(directory.glob("**/receipt.json"))]
                trial_metrics = validate_trial_set(receipts, root)
                checks.append({"name": "agent trial receipts", "ok": True, "reason": "passed"})
            except Exception as exc:
                checks.append({"name": "agent trial receipts", "ok": False, "reason": str(exc)})
    ok = all(item["ok"] for item in checks)
    receipt = {
        "ok": ok, "phase": "prepare-release", "check_only": check_only,
        "manifest_name": manifest.get("name", ""), "manifest_version": manifest.get("version", ""),
        "release_version": version, "release_base_version": base, "release_tag": base_release_tag(version),
        "package_hash": package_hash, "branch": branch.stdout.strip(), "commit": head.stdout.strip() if head.returncode == 0 else "",
        "dirty": dirty, "dirty_status": status.stdout.strip(),
        "changelog": {"has_unreleased": has_unreleased, "has_version_entry": has_version, "path": "CHANGELOG.md"},
        "required_gates": ["scripts/validate.sh", "scripts/sync-live.sh --validate", "git status --short"],
        "publish_ready": not dirty and has_version and ok, "agent_trial_metrics": trial_metrics,
        "release_evidence": release_evidence, "checks": checks,
    }
    output = arg_value(args, "OutputPath")
    if output:
        write_text(resolve_under(root, str(output), "OutputPath"), json.dumps(receipt, indent=2))
    return emit(receipt, 0 if ok else 1)


HANDLERS = {"command_prepare_release": command_prepare_release}
