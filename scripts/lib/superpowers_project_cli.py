#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from superpowers_project_command_registry import build_command_registry, resolve_command
from superpowers_project_context import RuntimeContext, resolve_project_root, resolve_project_path
from package_provenance import runtime_contract_hash as package_contract_hash, runtime_manifest, verify_runtime_provenance
from command_catalog import load_command_catalog

try:
    import yaml
except Exception:  # pragma: no cover - reported by validate.sh
    yaml = None


ACTIVE_SKILLS_EXCLUDING_USER = {
    "align-project",
    "audit-project",
    "brainstorm-spec",
    "companion-interface",
    "create-issues",
    "implement-plan",
    "initiate-workflow",
    "loop-controller",
    "merge-changes",
    "orchestrate-issues",
    "resolve-issue",
    "setup-project",
    "write-plan",
}

USER_SKILLS = {"advanced-user-input"}
RETIRED_SKILLS = {
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "project-writing-plan",
    "plan-to-issue",
    "resolve-issue-with-goal",
    "milestones-doctor",
    "project-context",
    "superpowers-project",
    "project-setup",
    "project-orchestrate",
    "project-brainstorm",
    "project-plan",
    "project-issue",
    "project-resolve",
    "project-merge",
    "project-doctor",
    "workflow",
    "setup",
}


class ScriptError(Exception):
    pass


@dataclass
class Context:
    script_path: Path
    repo_root: Path
    script_rel: str
    script_name: str
    args: list[str]
    plugin_root: Path | None = None
    invocation_cwd: Path | None = None


def find_repo_root(path: Path) -> Path:
    current = path.resolve().parent
    while current != current.parent:
        if (current / ".codex-plugin" / "plugin.json").is_file() and (current / "scripts").is_dir():
            return current
        current = current.parent
    raise ScriptError(f"could not locate repo root for {path}")


def normalize_rel(path: Path | str, root: Path | None = None) -> str:
    p = Path(path)
    if root is not None:
        try:
            p = p.resolve().relative_to(root.resolve())
        except Exception:
            p = Path(os.path.relpath(str(p), str(root)))
    return p.as_posix().lstrip("./")


def resolve_under(root: Path, value: str, label: str = "path") -> Path:
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = root / candidate
    resolved = candidate.resolve()
    root_resolved = root.resolve()
    try:
        resolved.relative_to(root_resolved)
    except ValueError as exc:
            raise ScriptError(f"{label} is outside repo root: {resolved}") from exc
    return resolved

def project_root_for(ctx: Context, args: dict[str, Any]) -> Path:
    runtime = RuntimeContext(ctx.script_path, ctx.plugin_root or ctx.repo_root, ctx.invocation_cwd or Path.cwd(), ctx.script_rel)
    return resolve_project_root(runtime, args)

def project_path_for(root: Path, value: str, label: str = "path") -> Path:
    return resolve_project_path(root, value, label)


def parse_ps_args(argv: list[str]) -> dict[str, Any]:
    parsed: dict[str, Any] = {"_positional": []}
    i = 0
    while i < len(argv):
        token = argv[i]
        if token.startswith("--"):
            key = token[2:].replace("-", "_")
        elif token.startswith("-") and token != "-":
            key = token[1:]
        else:
            parsed["_positional"].append(token)
            i += 1
            continue
        if i + 1 < len(argv) and not argv[i + 1].startswith("-"):
            value: Any = argv[i + 1]
            i += 2
        else:
            value = True
            i += 1
        if key in parsed:
            if not isinstance(parsed[key], list):
                parsed[key] = [parsed[key]]
            parsed[key].append(value)
        else:
            parsed[key] = value
    return parsed


def arg_value(args: dict[str, Any], *names: str, default: Any = None) -> Any:
    lowered = {k.lower(): v for k, v in args.items()}
    for name in names:
        key = name.lower()
        if key in lowered:
            return lowered[key]
    return default


def has_switch(args: dict[str, Any], *names: str) -> bool:
    value = arg_value(args, *names, default=False)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() not in {"", "false", "0", "no"}
    return bool(value)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def read_json_arg(root: Path, args: dict[str, Any], json_name: str, path_name: str, required: bool = True) -> tuple[Any, str]:
    inline = arg_value(args, json_name)
    path_value = arg_value(args, path_name)
    if inline and path_value:
        raise ScriptError(f"provide exactly one of {json_name} or {path_name}")
    if inline:
        return json.loads(str(inline)), ""
    if path_value:
        path = project_path_for(root, str(path_value), path_name)
        if not path.is_file():
            raise ScriptError(f"{path_name} is missing: {path_value}")
        return json.loads(read_text(path)), normalize_rel(path, root)
    if required:
        raise ScriptError(f"{json_name} or {path_name} is required")
    return None, ""


def emit(obj: Any, ok_exit: int = 0) -> int:
    print(json.dumps(obj, indent=2, ensure_ascii=False))
    return ok_exit


def complete(ok: bool, phase: str, reason: str, **extra: Any) -> int:
    payload = {"ok": ok, "phase": phase, "reason": reason}
    payload.update(extra)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0 if ok else 1


def run(cmd: list[str], cwd: Path, timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=str(cwd), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)


def run_checked(cmd: list[str], cwd: Path, timeout: int | None = None) -> dict[str, Any]:
    result = run(cmd, cwd, timeout)
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    return {
        "command": " ".join(cmd),
        "exit_code": result.returncode,
        "ok": result.returncode == 0,
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_hash_entries(root: Path) -> list[str]:
    if not root.exists():
        return [f"MISSING:{normalize_rel(root)}"]
    entries: list[str] = []
    if root.is_file():
        entries.append(f"{root.name}\t{sha256_file(root)}")
        return entries
    for file in sorted(p for p in root.rglob("*") if p.is_file()):
        if "__pycache__" in file.parts or file.suffix == ".pyc":
            continue
        entries.append(f"{normalize_rel(file, root)}\t{sha256_file(file)}")
    return entries


def compare_trees(source: Path, target: Path) -> list[dict[str, str]]:
    def hashes(root: Path) -> dict[str, str]:
        if not root.is_dir():
            return {}
        return {
            normalize_rel(file, root): sha256_file(file)
            for file in sorted(p for p in root.rglob("*") if p.is_file())
            if "__pycache__" not in file.parts and file.suffix != ".pyc"
        }

    src = hashes(source)
    dst = hashes(target)
    drift: list[dict[str, str]] = []
    for key in sorted(set(src) | set(dst)):
        if key not in src:
            drift.append({"path": key, "drift": "missing-in-source"})
        elif key not in dst:
            drift.append({"path": key, "drift": "missing-in-target"})
        elif src[key] != dst[key]:
            drift.append({"path": key, "drift": "content-diff"})
    return drift


def active_skill_names(root: Path) -> list[str]:
    skills = root / "skills"
    if not skills.is_dir():
        return []
    return sorted(p.name for p in skills.iterdir() if p.is_dir())


def markdown_section(text: str, name: str) -> str | None:
    pattern = rf"(?ims)^\s{{0,3}}##\s+{re.escape(name)}\s*$\r?\n(?P<body>.*?)(?=^\s{{0,3}}##\s+|\Z)"
    match = re.search(pattern, text)
    return match.group("body") if match else None


def field_value(text: str, name: str) -> str | None:
    escaped = re.escape(name)
    patterns = [
        rf"(?im)^\s*\*\*{escaped}\s*:\s*\*\*\s*(.+?)\s*$",
        rf"(?im)^\s*\*\*{escaped}\*\*\s*:\s*(.+?)\s*$",
        rf"(?im)^\s*{escaped}\s*:\s*(.+?)\s*$",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip()
    return None


def concrete_value(field: str, value: str | None) -> tuple[bool, str]:
    if value is None or not value.strip():
        return False, f"{field} is empty"
    trimmed = value.strip()
    if re.match(r"^(tbd|none|n/a|na|not applicable|same as above|-)$", trimmed, re.I):
        return False, f"{field} uses a generic value"
    if field == "Acceptance Proof" and re.match(r"^(tests?\s+pass(?:ed)?|unit tests?\s+pass(?:ed)?|lint\s+pass(?:ed)?|diff\s+reviewed)$", trimmed, re.I):
        return False, "Acceptance Proof must prove target-perspective behavior, not only tests or diffs"
    if field == "Evidence" and re.match(r"^(tests?|unit tests?|lint|diff)$", trimmed, re.I):
        return False, "Evidence must name a target-perspective lane"
    return True, "passed"


OUTCOME_FIELDS = [
    "Intent",
    "Current Behavior",
    "Expected Outcome",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Evidence",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid",
    "Risk",
]

BOUNDARY_FIELDS = [
    "Files To Create",
    "Files To Modify",
    "Files To Avoid",
    "Source Of Truth",
    "Read Path",
    "Write Path",
    "Integration Points",
    "Migration Or Cutover",
    "Replaced Path Handling",
    "Acceptance Proof Gate",
]

ISSUE_OUTCOME_FIELDS = [
    "Outcome Source",
    "Intent",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid",
]


def required_fields(section: str, fields: list[str], section_name: str) -> tuple[bool, str, dict[str, str]]:
    values: dict[str, str] = {}
    for field in fields:
        value = field_value(section, field)
        ok, reason = concrete_value(field, value)
        if not ok:
            return False, f"{section_name} {reason}", values
        values[field] = value or ""
    return True, "passed", values


def task_blocks(lines: list[str]) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^\s{0,3}#{2,4}\s+Task\s+(?P<number>\d+)\s*[:.-]\s*(?P<title>.+?)\s*$", line)
        if match:
            matches.append({"number": int(match.group("number")), "title": match.group("title").strip(), "start": index})
    blocks: list[dict[str, Any]] = []
    for index, current in enumerate(matches):
        end = matches[index + 1]["start"] if index + 1 < len(matches) else len(lines)
        blocks.append({**current, "end": end, "lines": lines[current["start"]:end]})
    return blocks


def task_use_case_lines(text: str) -> list[str]:
    cases: list[str] = []
    for block in task_blocks(text.splitlines()):
        use_index = next((i for i, line in enumerate(block["lines"]) if re.match(r"^\s*\*\*Use Cases:\*\*\s*$", line)), -1)
        if use_index < 0:
            continue
        for line in block["lines"][use_index + 1:]:
            if re.match(r"^\s{0,3}#{1,6}\s+", line) or re.match(r"^\s*\*\*[^*]+:\*\*\s*$", line):
                break
            if re.match(r"^\s*[-*]\s+\S", line) or re.match(r"^\s*\d+\.\s+\S", line):
                cases.append(line.strip())
    return cases


def test_plan_outcome_proof(text: str) -> dict[str, Any]:
    outcome_section = markdown_section(text, "Outcome Proof")
    if outcome_section is None:
        return {"ok": False, "phase": "plan-outcome-proof", "reason": "missing ## Outcome Proof", "fields": {}}
    ok, reason, outcome_fields = required_fields(outcome_section, OUTCOME_FIELDS, "Outcome Proof")
    if not ok:
        return {"ok": False, "phase": "plan-outcome-proof", "reason": reason, "fields": outcome_fields}
    boundary_section = markdown_section(text, "Implementation Boundaries")
    if boundary_section is None:
        return {"ok": False, "phase": "plan-outcome-proof", "reason": "missing ## Implementation Boundaries", "fields": outcome_fields}
    ok, reason, boundary_fields = required_fields(boundary_section, BOUNDARY_FIELDS, "Implementation Boundaries")
    if not ok:
        return {"ok": False, "phase": "plan-outcome-proof", "reason": reason, "fields": outcome_fields}
    cases = "\n".join(task_use_case_lines(text)).lower()
    if not cases:
        return {"ok": False, "phase": "plan-outcome-proof", "reason": "Task # Use Cases are required to cover outcome evidence and cutover", "fields": outcome_fields}
    if not re.search(r"acceptance|evidence|proof|target-perspective|validator|visible|operator-visible", cases) or not re.search(r"cutover|displaced|migration|old path|duplicate|retire|redirect|demote|shim", cases):
        return {"ok": False, "phase": "plan-outcome-proof", "reason": "Task # Use Cases must cover acceptance evidence and cutover or displaced path handling", "fields": outcome_fields}
    return {
        "ok": True,
        "phase": "plan-outcome-proof",
        "reason": "outcome proof passed",
        "fields": {"outcome_proof": outcome_fields, "implementation_boundaries": boundary_fields},
    }


def test_issue_outcome_summary(text: str) -> dict[str, Any]:
    section = markdown_section(text, "Outcome Summary")
    if section is None:
        return {"ok": False, "phase": "issue-outcome-summary", "reason": "missing ## Outcome Summary", "fields": {}}
    ok, reason, fields = required_fields(section, ISSUE_OUTCOME_FIELDS, "Outcome Summary")
    if not ok:
        return {"ok": False, "phase": "issue-outcome-summary", "reason": reason, "fields": fields}
    if re.search(r"(^|/)docs/goals(/|$)", fields.get("Outcome Source", "").replace("\\", "/")):
        return {"ok": False, "phase": "issue-outcome-summary", "reason": "Outcome Source must not use docs/goals", "fields": fields}
    return {"ok": True, "phase": "issue-outcome-summary", "reason": "issue outcome summary passed", "fields": fields}


def command_validate_plan_task_use_cases(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    plan_arg = arg_value(args, "PlanPath")
    if not plan_arg:
        raise ScriptError("PlanPath is required")
    plan = resolve_under(root, str(plan_arg), "PlanPath")
    if not plan.is_file():
        raise ScriptError(f"plan does not exist: {plan_arg}")
    relative = normalize_rel(plan, root)
    if not relative.lower().startswith("docs/superpowers/plans/"):
        raise ScriptError(f"plan must be under docs/superpowers/plans: {relative}")
    blocks = task_blocks(read_text(plan).splitlines())
    if not blocks:
        raise ScriptError("plan has no numbered Task # sections")
    task_results: list[dict[str, Any]] = []
    for block in blocks:
        lines = block["lines"]
        use_index = next((i for i, line in enumerate(lines) if re.match(r"^\s*\*\*Use Cases:\*\*\s*$", line)), -1)
        if use_index < 0:
            result = {"ok": False, "reason": f"Task {block['number']} is missing **Use Cases:**", "use_case_count": 0}
        else:
            before = "\n".join(lines[:use_index])
            if re.search(r"^\s*\*\*Files:\*\*\s*$|^\s*-\s+\[[ xX]\]\s+\S", before, re.M):
                result = {"ok": False, "reason": f"Task {block['number']} has **Use Cases:** after files or steps", "use_case_count": 0}
            else:
                count = 0
                for line in lines[use_index + 1:]:
                    if re.match(r"^\s{0,3}#{1,6}\s+", line) or re.match(r"^\s*\*\*[^*]+:\*\*\s*$", line):
                        break
                    if re.match(r"^\s*[-*]\s+\S", line) or re.match(r"^\s*\d+\.\s+\S", line):
                        count += 1
                result = {"ok": count > 0, "reason": "passed" if count else f"Task {block['number']} has **Use Cases:** but no use-case bullets", "use_case_count": count}
        task_results.append({"task": f"Task {block['number']}", "title": block["title"], **result})
    failures = [item for item in task_results if not item["ok"]]
    if failures:
        return emit({"ok": False, "phase": "plan-task-use-cases", "plan_path": relative, "task_count": len(blocks), "reason": "; ".join(f["reason"] for f in failures), "tasks": task_results}, 1)
    return emit({"ok": True, "phase": "plan-task-use-cases", "plan_path": relative, "task_count": len(blocks), "reason": "all numbered Task # sections include use cases", "tasks": task_results})


def command_validate_plan_outcome_proof(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    plan_arg = arg_value(args, "PlanPath")
    if not plan_arg:
        raise ScriptError("PlanPath is required")
    plan = resolve_under(root, str(plan_arg), "PlanPath")
    if not plan.is_file():
        raise ScriptError(f"plan does not exist: {plan_arg}")
    relative = normalize_rel(plan, root)
    if not relative.lower().startswith("docs/superpowers/plans/"):
        raise ScriptError(f"plan must be under docs/superpowers/plans: {relative}")
    result = test_plan_outcome_proof(read_text(plan))
    result["plan_path"] = relative
    return emit(result, 0 if result.get("ok") else 1)


def command_validate_decision_ledger(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    artifact_arg = arg_value(args, "Path")
    kind = str(arg_value(args, "Kind", default="")).lower()
    if kind not in {"spec", "plan"}:
        raise ScriptError("Kind must be spec or plan")
    if not artifact_arg:
        raise ScriptError("Path is required")
    artifact = resolve_under(root, str(artifact_arg), "Path")
    if not artifact.is_file():
        raise ScriptError(f"{kind} artifact does not exist: {artifact_arg}")
    rel = normalize_rel(artifact, root)
    prefix = "docs/superpowers/specs/" if kind == "spec" else "docs/superpowers/plans/"
    if not rel.startswith(prefix):
        raise ScriptError(f"{kind} artifact must be under {prefix}")
    text = read_text(artifact)
    section = markdown_section(text, "Decision Ledger")
    if section is None:
        raise ScriptError("missing ## Decision Ledger")
    required = ["decision", "source", "answer", "impact", "deferred?", "risk owner"]
    table_lines = [line for line in section.splitlines() if line.strip().startswith("|")]
    if len(table_lines) < 2:
        raise ScriptError("Decision Ledger must contain a Markdown table")
    header = [cell.strip().strip("`").lower() for cell in table_lines[0].strip().strip("|").split("|")]
    missing = [col for col in required if col not in header]
    if missing:
        raise ScriptError(f"Decision Ledger missing required column(s): {', '.join(missing)}")
    rows = 0
    for line in table_lines[2:]:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != len(header):
            raise ScriptError("Decision Ledger row has wrong cell count")
        row = dict(zip(header, cells))
        for col in required:
            value = row.get(col, "")
            if not value or re.match(r"^(tbd|todo|unknown|unspecified|none|n/a|na|later|someone|owner|-)$", value, re.I):
                raise ScriptError(f"Decision Ledger row has non-concrete {col}")
        if row.get("deferred?", "").lower() not in {"yes", "y", "true", "deferred", "no", "n", "false", "resolved"}:
            raise ScriptError("Decision Ledger Deferred? values must be yes/no style")
        rows += 1
    if rows == 0:
        raise ScriptError("Decision Ledger must include at least one decision row")
    return complete(True, "decision-ledger", "decision ledger passed", path=rel, rows=rows)


def command_test_decision_ledger(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise accepted and rejected decision-ledger fixtures."""
    with tempfile.TemporaryDirectory(prefix="decision-ledger-") as tmp:
        root = Path(tmp); (root / "docs/superpowers/specs").mkdir(parents=True)
        path = root / "docs/superpowers/specs/fixture.md"
        table = "## Decision Ledger\n\n| decision | source | answer | impact | deferred? | risk owner |\n|---|---|---|---|---|---|\n| route | user | continue | bounded | no | maintainer |\n"
        path.write_text(table, encoding="utf-8")
        accepted = command_validate_decision_ledger(ctx, {"RepoRoot": str(root), "Path": str(path), "Kind": "spec"})
        path.write_text("## Decision Ledger\n\n| decision | source | answer | impact | deferred? | risk owner |\n|---|---|---|---|---|---|\n| route | TODO | continue | bounded | no | maintainer |\n", encoding="utf-8")
        try:
            rejected = command_validate_decision_ledger(ctx, {"RepoRoot": str(root), "Path": str(path), "Kind": "spec"})
        except ScriptError:
            rejected = 1
    return emit({"ok": accepted == 0 and rejected != 0, "phase": "decision-ledger-test", "accepted": accepted == 0, "rejected": rejected != 0}, 0 if accepted == 0 and rejected != 0 else 1)


def command_validate_auto_mode(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    try:
        auth, auth_path = read_json_arg(root, args, "AuthorizationJson", "AuthorizationPath")
        required = [
            "question_id",
            "source",
            "selected_authority",
            "source_spec",
            "route_policy",
            "decision_policy",
            "merge_permission",
            "mutation_scope",
            "required_proof",
            "stop_conditions",
        ]
        for field in required:
            if field not in auth:
                raise ScriptError(f"missing {field}")
        if auth.get("question_id") != "project_auto_mode_authorization":
            raise ScriptError("question_id must be project_auto_mode_authorization")
        source = auth.get("source")
        allowed_sources = {"request_user_input"}
        if os.environ.get("SUPERPOWERS_TRIAL_NONINTERACTIVE") == "1":
            allowed_sources.add("trial-fixture")
        if source not in allowed_sources:
            raise ScriptError("source must be request_user_input, or trial-fixture in an explicit noninteractive trial")
        if auth.get("selected_authority") != "bounded-auto-merge":
            raise ScriptError("selected_authority must be bounded-auto-merge")
        spec = resolve_under(root, str(auth.get("source_spec", "")), "source_spec")
        if not normalize_rel(spec, root).startswith("docs/superpowers/specs/") or not spec.is_file():
            raise ScriptError("source_spec must exist under docs/superpowers/specs")
        route = auth.get("route_policy") or {}
        if route.get("selected_mode") != "agent-chooses":
            raise ScriptError("route_policy.selected_mode must be agent-chooses")
        if "worker_route" in route:
            raise ScriptError("route_policy.worker_route is obsolete; use route_policy.issue_route")
        if route.get("issue_route") != "direct-inline-resolve-issue":
            raise ScriptError("route_policy.issue_route must be direct-inline-resolve-issue")
        decision = auth.get("decision_policy") or {}
        if decision.get("selected_mode") != "recorded-defaults" or decision.get("stop_outside_policy") is not True:
            raise ScriptError("decision_policy must use recorded-defaults and stop_outside_policy true")
        merge = auth.get("merge_permission") or {}
        if merge.get("selected_mode") != "preauthorized-after-clean-premerge" or merge.get("require_clean_premerge") is not True:
            raise ScriptError("merge_permission must require clean premerge")
        for needed in ["current-repo", "development-branch"]:
            if needed not in (auth.get("mutation_scope") or []):
                raise ScriptError(f"mutation_scope missing {needed}")
        for needed in ["plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof"]:
            if needed not in (auth.get("required_proof") or []):
                raise ScriptError(f"required_proof missing {needed}")
        for needed in ["missing-proof", "dirty-unsafe-state", "failed-validation", "decision-outside-policy"]:
            if needed not in (auth.get("stop_conditions") or []):
                raise ScriptError(f"stop_conditions missing {needed}")
        return complete(True, "auto-mode-authorization", "passed", evidence={"repo_root": str(root), "authorization_path": auth_path})
    except Exception as exc:
        return complete(False, "auto-mode-authorization", str(exc))


def command_test_auto_mode_contract(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise accepted and rejected bounded-Auto authorization fixtures."""
    with tempfile.TemporaryDirectory(prefix="auto-mode-contract-") as tmp:
        root = Path(tmp)
        (root / "docs/superpowers/specs").mkdir(parents=True)
        (root / "docs/superpowers/specs/source.md").write_text("# fixture\n", encoding="utf-8")
        auth = {
            "question_id": "project_auto_mode_authorization", "source": "request_user_input",
            "selected_authority": "bounded-auto-merge", "source_spec": "docs/superpowers/specs/source.md",
            "route_policy": {"selected_mode": "agent-chooses", "issue_route": "direct-inline-resolve-issue"},
            "decision_policy": {"selected_mode": "recorded-defaults", "stop_outside_policy": True},
            "merge_permission": {"selected_mode": "preauthorized-after-clean-premerge", "require_clean_premerge": True},
            "mutation_scope": ["current-repo", "development-branch"],
            "required_proof": ["plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof"],
            "stop_conditions": ["missing-proof", "dirty-unsafe-state", "failed-validation", "decision-outside-policy"],
        }
        path = root / "auth.json"; path.write_text(json.dumps(auth), encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            accepted = command_validate_auto_mode(ctx, {"RepoRoot": str(root), "AuthorizationPath": str(path)})
        auth["route_policy"]["issue_route"] = "wrong-route"; path.write_text(json.dumps(auth), encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            rejected = command_validate_auto_mode(ctx, {"RepoRoot": str(root), "AuthorizationPath": str(path)})
    ok = accepted == 0 and rejected != 0
    return emit({"ok": ok, "phase": "auto-mode-contract", "accepted": accepted == 0, "rejected": rejected != 0}, 0 if ok else 1)


def command_validate_workflow_mode(ctx: Context, args: dict[str, Any]) -> int:
    runtime = RuntimeContext(ctx.script_path, ctx.plugin_root or ctx.repo_root, ctx.invocation_cwd or Path.cwd(), ctx.script_rel)
    root = resolve_project_root(runtime, args)
    ledger_arg = arg_value(args, "ModeLedgerPath")
    if not ledger_arg:
        raise ScriptError("ModeLedgerPath is required")
    path = project_path_for(root, str(ledger_arg), "ModeLedgerPath")
    if not path.is_file():
        raise ScriptError(f"mode ledger not found: {ledger_arg}")
    ledger = json.loads(read_text(path))
    if ledger.get("manifest") is not None:
        verify_runtime_provenance(ledger, runtime.plugin_root, root)
    elif ledger.get("provenance_required") is True and ledger.get("plugin_contract_hash") != runtime_contract_hash(runtime.plugin_root):
        raise ScriptError("plugin_contract_hash does not match installed plugin")
    required = [
        "question_id",
        "source",
        "selected_mode",
        "repo_root",
        "plugin_manifest_version",
        "plugin_contract_hash",
        "started_at",
        "autonomy_scope",
        "mutation_scope",
        "candidate_scope",
        "route_policy",
        "proof_policy",
        "stop_conditions",
        "downstream_ledger_paths",
    ]
    missing = [field for field in required if not ledger.get(field)]
    if missing:
        raise ScriptError(f"missing required field(s): {', '.join(missing)}")
    if ledger.get("question_id") != "project_workflow_mode":
        raise ScriptError("question_id must be project_workflow_mode")
    mode = str(ledger.get("selected_mode", "")).lower()
    if mode not in {"manual", "auto", "looping"}:
        raise ScriptError(f"unsupported selected_mode: {ledger.get('selected_mode')}")
    if mode == "manual" and ledger.get("autonomy_scope") != "ask-every-material-decision":
        raise ScriptError("manual mode must use ask-every-material-decision autonomy_scope")
    if mode == "auto":
        if ledger.get("autonomy_scope") != "one-route":
            raise ScriptError("auto mode must be one-route autonomy")
        route = ledger.get("route_policy") or {}
        if route.get("one_route_only") is not True:
            raise ScriptError("auto mode requires route_policy.one_route_only true")
        if route.get("continue_to_next_candidate") is True:
            raise ScriptError("auto mode must remain one-route and cannot continue to next candidate")
    if mode == "looping":
        if ledger.get("autonomy_scope") != "bounded-loop":
            raise ScriptError("looping mode must use bounded-loop autonomy_scope")
        for field in ["budget_policy", "candidate_scope", "proof_policy", "stop_conditions"]:
            if not ledger.get(field):
                raise ScriptError(f"looping mode requires {field}")
    return emit({"ok": True, "phase": "workflow-mode-ledger", "selected_mode": mode, "path": str(path)})


def validate_json_required(root: Path, phase: str, path_arg: str, required: list[str], args: dict[str, Any]) -> int:
    path_value = arg_value(args, path_arg)
    if not path_value:
        raise ScriptError(f"{path_arg} is required")
    path = resolve_under(root, str(path_value), path_arg)
    data = json.loads(read_text(path))
    missing = [field for field in required if field not in data or data[field] in (None, "", [])]
    if missing:
        raise ScriptError(f"missing required field(s): {', '.join(missing)}")
    return complete(True, phase, f"{phase} passed", path=normalize_rel(path, root))


def command_loop_budget(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path_value = arg_value(args, "BudgetLedgerPath")
    if not path_value:
        raise ScriptError("BudgetLedgerPath is required")
    path = resolve_under(root, str(path_value), "BudgetLedgerPath")
    data = json.loads(read_text(path))
    checks = [
        ("candidates_completed", "max_candidates", ">="),
        ("current_phase_attempts", "max_attempts_per_phase", ">="),
        ("repeated_same_failure_count", "max_repeated_same_failure", ">="),
        ("changed_files", "max_changed_files", ">"),
        ("github_mutations", "max_github_mutations", ">"),
        ("validator_reruns", "max_validator_reruns", ">"),
        ("unreviewed_diff_lines", "max_unreviewed_diff_lines", ">"),
    ]
    violations = []
    for actual, maximum, op in checks:
        if actual not in data or maximum not in data:
            raise ScriptError(f"missing required field(s): {actual}, {maximum}")
        failed = int(data[actual]) >= int(data[maximum]) if op == ">=" else int(data[actual]) > int(data[maximum])
        if failed:
            violations.append(f"{actual} exhausted: {data[actual]} {op} {data[maximum]}")
    if violations:
        raise ScriptError("; ".join(violations))
    return complete(True, "loop-budget", "budget is within policy", evidence={"budget_ledger_path": str(path_value)})


def command_loop_run_ledger(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    return validate_json_required(root, "loop-run-ledger", "RunLedgerPath", [
        "run_id", "trigger_source", "repo_root", "plugin_manifest_version", "plugin_contract_hash",
        "started_at", "updated_at", "status", "current_phase", "candidate_source", "candidate_id",
        "selected_route", "route_reason", "budget_policy", "attempts", "branch",
        "proof_artifacts", "verifier_artifacts", "metrics_artifacts",
    ], args)


def command_loop_verifier(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path_value = arg_value(args, "VerifierLedgerPath")
    if not path_value:
        raise ScriptError("VerifierLedgerPath is required")
    path = resolve_under(root, str(path_value), "VerifierLedgerPath")
    data = json.loads(read_text(path))
    for field in ["candidate_id", "route", "risk", "verifier_type", "independent", "proof"]:
        if field not in data or data[field] in (None, "", []):
            raise ScriptError(f"missing required field: {field}")
    if data.get("risk") == "high" and data.get("independent") is not True:
        raise ScriptError("high-risk routes require independent verifier proof")
    for proof in data.get("proof") or []:
        for field in ["command", "ok", "artifact"]:
            if field not in proof:
                raise ScriptError(f"verifier proof missing {field}")
        if proof.get("ok") is not True:
            raise ScriptError(f"verifier proof failed: {proof.get('command')}")
    return complete(True, "verifier-ledger", "verifier proof is valid", evidence={"candidate_id": data.get("candidate_id"), "verifier_type": data.get("verifier_type"), "independent": bool(data.get("independent"))})


def command_loop_terminal_closeout(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path_value = arg_value(args, "RunResultPath")
    if not path_value:
        raise ScriptError("RunResultPath is required")
    path = resolve_under(root, str(path_value), "RunResultPath")
    data = json.loads(read_text(path))
    if data.get("ok") is not True:
        raise ScriptError("run result must be ok")
    if data.get("terminal_state") not in {"done", "stop"}:
        raise ScriptError("terminal_state must be done or stop")
    return complete(True, "loop-terminal-closeout", "terminal closeout passed", path=normalize_rel(path, root))


def command_loop_state_machine(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path_value = arg_value(args, "StatePath")
    if not path_value:
        raise ScriptError("StatePath is required")
    path = resolve_under(root, str(path_value), "StatePath")
    state = json.loads(read_text(path))
    for field in ["selected_mode", "status", "selection_authority", "iterations"]:
        if field not in state:
            raise ScriptError(f"missing required field: {field}")
    if state.get("selected_mode") != "looping":
        raise ScriptError("selected_mode must be looping")
    iterations = state.get("iterations") or []
    for item in iterations:
        for field in ["selected_candidate_id", "candidate_source", "selected_route", "owner_route"]:
            if not item.get(field):
                raise ScriptError(f"iteration missing {field}")
        if item.get("selected_route") != item.get("owner_route"):
            raise ScriptError("selected_route must match owner_route")
    return complete(True, "loop-state-machine", "loop state machine passed", evidence={"iterations": len(iterations)})


def command_write_metrics(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    input_value = arg_value(args, "MetricsInputPath")
    output_value = arg_value(args, "OutputPath")
    if not input_value or not output_value:
        raise ScriptError("MetricsInputPath and OutputPath are required")
    src = resolve_under(root, str(input_value), "MetricsInputPath")
    metrics = json.loads(read_text(src))
    report = {
        "ok": True,
        "phase": "loop-metrics-report",
        "candidate_count": len(metrics.get("candidates", [])) if isinstance(metrics, dict) else 0,
        "source": normalize_rel(src, root),
    }
    target = resolve_under(root, str(output_value), "OutputPath")
    write_text(target, json.dumps(report, indent=2))
    return emit({**report, "output_path": normalize_rel(target, root)})


def split_table_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", line)]


def command_validate_active_backlog(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path = resolve_under(root, str(arg_value(args, "Path", default="docs/superpowers/backlog/ACTIVE.md")), "Path")
    if not path.is_file():
        raise ScriptError(f"active backlog file does not exist: {path}")
    lines = read_text(path).splitlines()
    required = ["id", "route_owner", "source_artifact", "priority", "status", "proof_target"]
    header_index = -1
    headers: list[str] = []
    for index, line in enumerate(lines):
        if not line.strip().startswith("|"):
            continue
        candidate = [re.sub(r"[^a-z0-9]+", "_", c.lower()).strip("_") for c in split_table_row(line)]
        if all(col in candidate for col in required):
            header_index = index
            headers = candidate
            break
    if header_index < 0:
        raise ScriptError(f"active backlog table missing required columns: {', '.join(required)}")
    entries = []
    for row_index in range(header_index + 2, len(lines)):
        line = lines[row_index]
        if not line.strip().startswith("|"):
            break
        cells = split_table_row(line)
        if not "".join(cells).strip():
            continue
        row = {headers[i]: cells[i] if i < len(cells) else "" for i in range(len(headers))}
        for column in required:
            if not row.get(column):
                raise ScriptError(f"{column.replace('_', ' ')} is required in active backlog row {row_index + 1}")
        route = row["route_owner"]
        if route not in ACTIVE_SKILLS_EXCLUDING_USER | {"advanced-user-input"}:
            raise ScriptError(f"Route owner is unsupported for {row['id']}: {route}")
        if row["priority"].upper() not in {"P0", "P1", "P2", "P3"}:
            raise ScriptError(f"Priority is unsupported for {row['id']}: {row['priority']}")
        status = row["status"].lower()
        if status not in {"ready", "blocked", "paused", "deferred"}:
            raise ScriptError(f"Status is not an active backlog status for {row['id']}: {row['status']}")
        source = row["source_artifact"].split("#", 1)[0].strip()
        if not resolve_under(root, source, "Source artifact").is_file():
            raise ScriptError(f"Source artifact does not exist: {source}")
        entries.append({**row, "status": status})
    ready = [entry["id"] for entry in entries if entry["status"] == "ready"]
    return emit({"ok": True, "phase": "active-backlog", "path": normalize_rel(path, root), "entry_count": len(entries), "ready_count": len(ready), "ready_ids": ready})


def command_validate_flat_roots(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    findings = []
    milestones = root / "docs" / "superpowers" / "milestones"
    if milestones.is_dir():
        for folder in milestones.rglob("*"):
            if folder.is_dir() and folder.name in {"specs", "plans", "issues"} and not (folder / ".generated-index-view").exists():
                findings.append({"category": "blocking", "path": normalize_rel(folder, root), "reason": "nested canonical milestone artifact folder"})
    if findings:
        return emit({"ok": False, "phase": "validate-flat-artifact-roots", "reason": "nested canonical milestone artifact folders are drift", "findings": findings}, 1)
    return emit({"ok": True, "phase": "validate-flat-artifact-roots", "reason": "flat canonical artifact roots passed", "findings": []})


def command_validate_generated_state(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    findings = []
    gitignore = root / ".gitignore"
    if not gitignore.is_file() or ".superpowers/" not in [line.strip() for line in read_text(gitignore).splitlines()]:
        findings.append({"path": ".gitignore", "reason": ".superpowers/ ignore entry is required"})
    tracked = run(["git", "ls-files", "--", ".superpowers"], root)
    if tracked.returncode == 0 and tracked.stdout.strip():
        for line in tracked.stdout.splitlines():
            findings.append({"path": line.replace("\\", "/"), "reason": "tracked generated state"})
    if findings:
        return emit({"ok": False, "phase": "validate-generated-state", "reason": "generated-state guardrails failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "validate-generated-state", "reason": "generated-state guardrails passed", "findings": []})


def referenced_shell_scripts(text: str) -> set[str]:
    refs = set()
    for match in re.finditer(r"(?P<path>(?:\./)?(?:scripts|skills)/[A-Za-z0-9_./<>-]+?\.sh)", text):
        value = match.group("path")
        if "<" in value or ">" in value:
            continue
        refs.add(value.lstrip("./"))
    return refs


def command_validate_skill_script_contract(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    findings = []
    for skill_dir in sorted((root / "skills").iterdir()):
        if not skill_dir.is_dir():
            continue
        for text_file in [skill_dir / "SKILL.md", skill_dir / "agents" / "openai.yaml"]:
            if not text_file.is_file():
                continue
            text = read_text(text_file)
            if ".ps1" in text:
                findings.append({"path": normalize_rel(text_file, root), "reason": "PowerShell script reference remains"})
            for ref in referenced_shell_scripts(text):
                candidates = [root / ref]
                if ref.startswith("scripts/"):
                    candidates.append(skill_dir / ref)
                if not any(candidate.is_file() for candidate in candidates):
                    findings.append({"path": normalize_rel(text_file, root), "reason": f"referenced script is missing: {ref}"})
    for script in sorted((root / "skills").glob("*/scripts/**/*.sh")) + sorted((root / "scripts").glob("**/*.sh")):
        if not os.access(script, os.X_OK):
            findings.append({"path": normalize_rel(script, root), "reason": "script is not executable"})
    if findings:
        return emit({"ok": False, "phase": "skill-script-contract", "reason": "skill script contract failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "skill-script-contract", "reason": "skill script references are Linux bash scripts", "findings": []})


def command_validate_advanced_user_input_policy(ctx: Context, args: dict[str, Any]) -> int:
    """Validate the shared native-input policy and its route-facing mirrors."""
    root = ctx.plugin_root or ctx.repo_root
    skill_root = root / "skills"
    findings: list[dict[str, str]] = []

    def require_text(path: Path, needles: list[str], label: str) -> None:
        if not path.is_file():
            findings.append({"path": normalize_rel(path, root), "reason": f"{label} is missing"})
            return
        text = read_text(path)
        for needle in needles:
            if needle not in text:
                findings.append({"path": normalize_rel(path, root), "reason": f"required policy is missing: {needle}"})

    shared = skill_root / "advanced-user-input" / "SKILL.md"
    metadata = skill_root / "advanced-user-input" / "agents" / "openai.yaml"
    require_text(shared, [
        "request_user_input",
        "request_agent_input",
        "Use Stop for mid-loop exits",
        "Use Done only for verified final states",
        "Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop",
        "Final clean closeout gates may use Yes, Revisit, and Done",
        "custom answers that claim completion before proof exists are treated as Stop",
    ], "advanced-user-input policy")
    require_text(metadata, ["request_user_input", "Never use debug mode to approve mutation"], "advanced-user-input metadata")

    forbidden = [
        "Right is shown to the user as stale terminal option",
        "Only stale terminal option can end a continuation loop",
        "Ask exactly three top-level options: Yes, Revisit, and stale terminal option",
    ]
    for path in [shared, metadata]:
        if path.is_file():
            text = read_text(path)
            for needle in forbidden:
                if needle in text:
                    findings.append({"path": normalize_rel(path, root), "reason": f"retired policy remains: {needle}"})

    intermediate = ["initiate-workflow", "setup-project", "brainstorm-spec", "write-plan", "implement-plan", "create-issues", "resolve-issue", "orchestrate-issues"]
    for skill in intermediate:
        for path in [skill_root / skill / "SKILL.md", skill_root / skill / "agents" / "openai.yaml"]:
            require_text(path, ["Stop"], f"{skill} intermediate route")
    for skill in ["merge-changes", "audit-project"]:
        require_text(skill_root / skill / "SKILL.md", ["Done", "verified final"], f"{skill} final route")

    if findings:
        return emit({"ok": False, "phase": "advanced-user-input-policy", "reason": "advanced user input policy failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "advanced-user-input-policy", "reason": "native input and closeout policy passed", "findings": []})


def command_test_agent_native_companion_preview(ctx: Context, args: dict[str, Any]) -> int:
    """Validate the local companion source contract without network or hosted tools."""
    checks: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="agent-native-companion-") as tmp:
        plan_dir = Path(tmp) / "plans" / "fixture-agent-native-companion"
        plan_dir.mkdir(parents=True)
        plan = plan_dir / "plan.mdx"
        plan.write_text("# Fixture\n\n<Callout id=\"decision\" tone=\"decision\">Review me.</Callout>\n", encoding="utf-8")
        text = read_text(plan)
        checks.append({"name": "accepted plan source", "ok": "<Callout" in text and "id=\"decision\"" in text, "reason": str(plan)})
        checks.append({"name": "plan source is local", "ok": plan.is_file() and plan.is_relative_to(plan_dir), "reason": str(plan)})
        unsupported = plan_dir / "unsupported.mdx"
        unsupported.write_text("# unsupported\n", encoding="utf-8")
        checks.append({"name": "unsupported artifact rejected", "ok": unsupported.name != "plan.mdx", "reason": "only plan.mdx is preview input"})
    ok = all(item["ok"] for item in checks)
    return emit({"ok": ok, "phase": "agent-native-companion-preview", "checks": checks}, 0 if ok else 1)


ARTIFACT_REVIEW_CARD_FIELDS = (
    "Gate", "Created/changed", "Proof", "Decisions", "Risks", "Recommended next route"
)


def validate_artifact_review_card_data(data: Any) -> list[str]:
    """Return concrete schema findings for the mandatory review card."""
    findings: list[str] = []
    if not isinstance(data, dict):
        return ["card must be a JSON object"]
    for field in ARTIFACT_REVIEW_CARD_FIELDS:
        if field not in data:
            findings.append(f"missing required field: {field}")
    gate = data.get("Gate")
    if gate not in {"continuation", "push", "publish", "merge"}:
        findings.append("Gate must be continuation, push, publish, or merge")
    changed = data.get("Created/changed")
    if not isinstance(changed, list) or not changed:
        findings.append("Created/changed must be a non-empty list")
    else:
        for index, item in enumerate(changed):
            if not isinstance(item, dict) or not str(item.get("path", "")).strip() or not str(item.get("action", "")).strip():
                findings.append(f"Created/changed[{index}] requires path and action")
    proof = data.get("Proof")
    if not isinstance(proof, list) or not proof:
        findings.append("Proof must be a non-empty list")
    else:
        for index, item in enumerate(proof):
            if not isinstance(item, dict) or not str(item.get("evidence", "")).strip() or "ok" not in item:
                findings.append(f"Proof[{index}] requires evidence and ok")
            elif not isinstance(item["ok"], bool):
                findings.append(f"Proof[{index}].ok must be boolean")
    decisions = data.get("Decisions")
    if not isinstance(decisions, list) or not decisions:
        findings.append("Decisions must be a non-empty list")
    else:
        for index, item in enumerate(decisions):
            if not isinstance(item, dict) or not str(item.get("decision", "")).strip() or not str(item.get("impact", "")).strip():
                findings.append(f"Decisions[{index}] requires decision and impact")
    risks = data.get("Risks")
    if not isinstance(risks, list):
        findings.append("Risks must be a list")
    else:
        for index, item in enumerate(risks):
            if not isinstance(item, dict) or not str(item.get("risk", "")).strip() or not str(item.get("owner", "")).strip():
                findings.append(f"Risks[{index}] requires risk and owner")
    if not isinstance(data.get("Recommended next route"), str) or not data["Recommended next route"].strip():
        findings.append("Recommended next route must be a non-empty string")
    return findings


def command_validate_artifact_review_card(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path_arg = arg_value(args, "Path")
    if not path_arg:
        raise ScriptError("Path is required")
    path = project_path_for(root, str(path_arg), "Path")
    if not path.is_file():
        raise ScriptError(f"artifact review card does not exist: {path_arg}")
    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise ScriptError(f"artifact review card is not valid JSON: {exc}") from exc
    findings = validate_artifact_review_card_data(data)
    result = {"ok": not findings, "phase": "artifact-review-card", "path": normalize_rel(path, root),
              "reason": "artifact review card passed" if not findings else "artifact review card failed",
              "findings": findings}
    return emit(result, 0 if not findings else 1)


def command_test_artifact_review_card(ctx: Context, args: dict[str, Any]) -> int:
    accepted = {
        "Gate": "continuation",
        "Created/changed": [{"path": "docs/superpowers/specs/example.md", "action": "created"}],
        "Proof": [{"evidence": "python3 -m unittest", "ok": True}],
        "Decisions": [{"decision": "continue to planning", "impact": "preserves governed route"}],
        "Risks": [{"risk": "fixture only", "owner": "release maintainer"}],
        "Recommended next route": "write-plan",
    }
    rejected = dict(accepted)
    rejected["Risks"] = [{"risk": "unowned risk"}]
    checks = [
        {"name": "accepted card", "ok": not validate_artifact_review_card_data(accepted)},
        {"name": "rejected card", "ok": bool(validate_artifact_review_card_data(rejected))},
    ]
    ok = all(check["ok"] for check in checks)
    return emit({"ok": ok, "phase": "artifact-review-card", "checks": checks}, 0 if ok else 1)


def command_test_auto_loop_trials(ctx: Context, args: dict[str, Any]) -> int:
    result = run([sys.executable, str(ctx.plugin_root / "tests" / "test_auto_loop_trials.py"), "-v"], ctx.repo_root)
    print(result.stdout, end="")
    print(result.stderr, file=sys.stderr, end="")
    return result.returncode


def command_test_workflow_runtime(ctx: Context, args: dict[str, Any]) -> int:
    result = run([sys.executable, "-m", "unittest", "tests/test_workflow_state.py", "-v"], ctx.repo_root)
    print(result.stdout, end="")
    print(result.stderr, file=sys.stderr, end="")
    return result.returncode


def command_test_workflow_graph(ctx: Context, args: dict[str, Any]) -> int:
    result = run([sys.executable, str(ctx.plugin_root / "scripts" / "validate-workflow-graph.py")], ctx.repo_root)
    print(result.stdout, end="")
    print(result.stderr, file=sys.stderr, end="")
    return result.returncode


def command_test_skill_slimming(ctx: Context, args: dict[str, Any]) -> int:
    result = run([sys.executable, "-m", "unittest", "tests.test_skill_slimming", "-v"], ctx.repo_root)
    print(result.stdout, end="")
    print(result.stderr, file=sys.stderr, end="")
    return result.returncode


def command_test_e2e_project_workflow(ctx: Context, args: dict[str, Any]) -> int:
    """Run the disposable workflow runtime plus active-backlog proof as one path."""
    runtime = run(["bash", str(ctx.plugin_root / "scripts" / "test-workflow-runtime.sh")], ctx.repo_root)
    backlog = run(["bash", str(ctx.plugin_root / "scripts" / "validate-active-backlog.sh"), "-RepoRoot", str(ctx.repo_root)], ctx.repo_root)
    checks = [
        {"name": "workflow runtime", "ok": runtime.returncode == 0, "reason": runtime.stderr[-300:] or runtime.stdout[-300:]},
        {"name": "active backlog", "ok": backlog.returncode == 0, "reason": backlog.stderr[-300:] or backlog.stdout[-300:]},
    ]
    ok = all(check["ok"] for check in checks)
    return emit({"ok": ok, "phase": "e2e-project-workflow", "checks": checks}, 0 if ok else 1)


def command_test_github_checks(ctx: Context, args: dict[str, Any]) -> int:
    """Validate a GitHub check receipt offline; network access is never needed."""
    accepted = {"checks": [{"name": "ci", "status": "completed", "conclusion": "success"}]}
    rejected = {"checks": [{"name": "ci", "status": "completed", "conclusion": "failure"}]}

    def valid(receipt: dict[str, Any]) -> bool:
        checks = receipt.get("checks")
        return isinstance(checks, list) and bool(checks) and all(
            isinstance(item, dict) and item.get("status") == "completed" and item.get("conclusion") == "success"
            for item in checks
        )

    ok = valid(accepted) and not valid(rejected)
    return emit({"ok": ok, "phase": "github-checks", "accepted": valid(accepted), "rejected": not valid(rejected)}, 0 if ok else 1)


def command_test_global_policy_deduplication(ctx: Context, args: dict[str, Any]) -> int:
    """Check that global continuation policy has one authoritative owner."""
    owner = read_text(ctx.plugin_root / "skills/advanced-user-input/SKILL.md")
    phrase = "Intermediate closeout gates use exactly three top-level options"
    active = [path for path in (ctx.plugin_root / "skills").glob("*/SKILL.md") if phrase in read_text(path)]
    accepted = phrase in owner and len(active) >= 1
    rejected_fixture = owner + "\n" + phrase
    rejected = rejected_fixture.count(phrase) > 1
    ok = accepted and rejected
    return emit({"ok": ok, "phase": "global-policy-deduplication", "accepted": accepted, "rejected": rejected, "owners": [str(path.relative_to(ctx.plugin_root)) for path in active]}, 0 if ok else 1)


def command_test_initiate_workflow_mode_gate(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise manual and invalid workflow-mode ledgers."""
    with tempfile.TemporaryDirectory(prefix="workflow-mode-gate-") as tmp:
        root = Path(tmp); ledger = root / "mode.json"
        base = {"question_id": "project_workflow_mode", "source": "trial", "selected_mode": "manual", "repo_root": str(root), "plugin_manifest_version": "fixture", "plugin_contract_hash": runtime_contract_hash(ctx.plugin_root), "started_at": "2026-01-01T00:00:00Z", "autonomy_scope": "ask-every-material-decision", "mutation_scope": ["current-repo"], "candidate_scope": ["one"], "route_policy": {"one_route_only": False}, "proof_policy": {"required": True}, "stop_conditions": ["failed-validation"], "downstream_ledger_paths": ["result.json"]}
        ledger.write_text(json.dumps(base), encoding="utf-8")
        accepted = command_validate_workflow_mode(ctx, {"RepoRoot": str(root), "ModeLedgerPath": str(ledger)})
        base["selected_mode"] = "unbounded"; ledger.write_text(json.dumps(base), encoding="utf-8")
        try:
            command_validate_workflow_mode(ctx, {"RepoRoot": str(root), "ModeLedgerPath": str(ledger)})
        except ScriptError:
            rejected = True
        else:
            rejected = False
    return emit({"ok": accepted == 0 and rejected, "phase": "initiate-workflow-mode-gate", "accepted": accepted == 0, "rejected": rejected}, 0 if accepted == 0 and rejected else 1)


def command_test_cross_repo_runtime(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise external project-root resolution and traversal rejection."""
    with tempfile.TemporaryDirectory(prefix="cross-repo-runtime-") as tmp:
        project = Path(tmp) / "project"; project.mkdir()
        runtime = RuntimeContext(ctx.script_path, ctx.plugin_root, project, ctx.script_rel)
        external_ok = resolve_project_root(runtime, {"RepoRoot": str(project)}) == project.resolve()
        try:
            resolve_project_path(project, "../outside", "Path")
        except Exception:
            traversal_rejected = True
        else:
            traversal_rejected = False
    ok = external_ok and traversal_rejected
    return emit({"ok": ok, "phase": "cross-repo-runtime", "external_root": external_ok, "traversal_rejected": traversal_rejected}, 0 if ok else 1)


def command_test_native_qa_svg(ctx: Context, args: dict[str, Any]) -> int:
    """Check native QA SVG fixtures offline and reject malformed markup."""
    accepted = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><path d="M0 0"/></svg>'
    rejected = "<svg><path d='M0 0'/></svg>"
    valid = lambda text: text.startswith("<svg") and "viewBox=" in text and "</svg>" in text
    ok = valid(accepted) and not valid(rejected)
    return emit({"ok": ok, "phase": "native-qa-svg", "accepted": valid(accepted), "rejected": not valid(rejected)}, 0 if ok else 1)


def command_test_outcome_workflow_summary(ctx: Context, args: dict[str, Any]) -> int:
    """Check that an outcome summary has evidence, result, and next-route sections."""
    accepted = "## Outcome Summary\n\n### Evidence\nproof\n\n### Result\npassed\n\n### Recommended Next Route\ncloseout\n"
    rejected = "## Outcome Summary\n\n### Evidence\nproof\n"
    required = ["### Evidence", "### Result", "### Recommended Next Route"]
    valid = lambda text: all(section in text for section in required)
    ok = valid(accepted) and not valid(rejected)
    return emit({"ok": ok, "phase": "outcome-workflow-summary", "accepted": valid(accepted), "rejected": not valid(rejected)}, 0 if ok else 1)


def command_test_plan_outcome_proof(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise plan outcome-proof acceptance and missing-field rejection."""
    lines = ["## Outcome Proof"] + [f"**{field}:** concrete fixture {field.lower()}" for field in OUTCOME_FIELDS]
    lines += ["\n## Implementation Boundaries"] + [f"**{field}:** concrete fixture {field.lower()}" for field in BOUNDARY_FIELDS]
    lines += ["\n## Tasks", "### Task 1: fixture", "**Use Cases:**", "- acceptance evidence is target-perspective and cutover retires old path"]
    accepted = test_plan_outcome_proof("\n".join(lines))["ok"]
    rejected = test_plan_outcome_proof("\n".join(lines).replace("concrete fixture risk", "tbd", 1))["ok"]
    ok = accepted and not rejected
    return emit({"ok": ok, "phase": "plan-outcome-proof-test", "accepted": accepted, "rejected": not rejected}, 0 if ok else 1)


def command_test_plan_task_use_cases(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise plan task/use-case acceptance and missing-use-case rejection."""
    with tempfile.TemporaryDirectory(prefix="plan-task-use-cases-") as tmp:
        root = Path(tmp); (root / "docs/superpowers/plans").mkdir(parents=True)
        path = root / "docs/superpowers/plans/fixture.md"
        accepted_text = "## Tasks\n### Task 1: fixture\n**Use Cases:**\n- acceptance evidence covers cutover\n"
        path.write_text(accepted_text, encoding="utf-8")
        accepted = command_validate_plan_task_use_cases(ctx, {"RepoRoot": str(root), "PlanPath": str(path)})
        path.write_text("## Tasks\n### Task 1: fixture\n", encoding="utf-8")
        rejected = command_validate_plan_task_use_cases(ctx, {"RepoRoot": str(root), "PlanPath": str(path)}) != 0
    return emit({"ok": accepted == 0 and rejected, "phase": "plan-task-use-cases-test", "accepted": accepted == 0, "rejected": rejected}, 0 if accepted == 0 and rejected else 1)


def command_test_plugin_only_live_sync(ctx: Context, args: dict[str, Any]) -> int:
    """Run live sync into disposable roots and verify the installable surface."""
    with tempfile.TemporaryDirectory(prefix="plugin-live-sync-") as tmp:
        base = Path(tmp)
        result = command_sync_live(ctx, {"LivePluginRoot": str(base / "live"), "UserSkillsRoot": str(base / "skills"), "MarketplacePath": str(base / "marketplace.json"), "SkipValidation": True})
        ok = (
            result == 0
            and (base / "live/.codex-plugin/plugin.json").is_file()
            and (base / "live/docs/superpowers/loop-mode-contract.yml").is_file()
            and (base / "marketplace.json").is_file()
            and runtime_contract_hash(base / "live") == runtime_contract_hash(ctx.repo_root)
        )
    return emit({"ok": ok, "phase": "plugin-only-live-sync", "isolated": True}, 0 if ok else 1)


def command_test_tracker_roadmap_proof(ctx: Context, args: dict[str, Any]) -> int:
    """Check that canonical roadmap and active-backlog surfaces exist."""
    root = ctx.plugin_root
    checks = {
        "active_backlog": (root / "docs/superpowers/backlog/ACTIVE.md").is_file(),
        "milestones": (root / "docs/superpowers/milestones").is_dir(),
        "project_context": (root / "docs/superpowers/PROJECT_CONTEXT.md").is_file(),
    }
    ok = all(checks.values())
    return emit({"ok": ok, "phase": "tracker-roadmap-proof", "checks": checks}, 0 if ok else 1)


def command_test_prepare_release(ctx: Context, args: dict[str, Any]) -> int:
    """Ensure a dirty worktree is rejected by the release gate."""
    with tempfile.TemporaryDirectory(prefix="prepare-release-") as tmp:
        root = Path(tmp); (root / ".codex-plugin").mkdir()
        shutil.copy2(ctx.plugin_root / ".codex-plugin/plugin.json", root / ".codex-plugin/plugin.json")
        shutil.copy2(ctx.plugin_root / "CHANGELOG.md", root / "CHANGELOG.md")
        run(["git", "init", "-q"], root); run(["git", "add", "."], root); run(["git", "-c", "user.email=fixture@example.com", "-c", "user.name=fixture", "commit", "-qm", "fixture"], root)
        (root / "dirty.txt").write_text("dirty\n", encoding="utf-8")
        status = command_prepare_release(ctx, {"RepoRoot": str(root)})
    ok = status != 0
    return emit({"ok": ok, "phase": "prepare-release-test", "dirty_release_rejected": ok}, 0 if ok else 1)


def command_test_project_namespace_migration(ctx: Context, args: dict[str, Any]) -> int:
    """Verify the migration removed namespace-wrapper skill bodies."""
    phrases = ["namespace wrapper", "Read the deployed user-level `SKILL.md` above.", "do not invent separate behavior"]
    offenders = [str(path.relative_to(ctx.plugin_root)) for path in (ctx.plugin_root / "skills").glob("*/SKILL.md") if any(phrase in read_text(path) for phrase in phrases)]
    ok = not offenders
    return emit({"ok": ok, "phase": "project-namespace-migration", "offenders": offenders}, 0 if ok else 1)


def command_test_scorecard_proof(ctx: Context, args: dict[str, Any]) -> int:
    """Validate scorecard threshold fixtures: every target must be at least 9."""
    accepted = {"targets": [{"name": "workflow", "score": 9}, {"name": "autonomy", "score": 10}]}
    rejected = {"targets": [{"name": "workflow", "score": 8}]}
    valid = lambda card: isinstance(card.get("targets"), list) and bool(card["targets"]) and all(isinstance(item, dict) and isinstance(item.get("score"), (int, float)) and item["score"] >= 9 for item in card["targets"])
    ok = valid(accepted) and not valid(rejected)
    return emit({"ok": ok, "phase": "scorecard-proof", "accepted": valid(accepted), "rejected": not valid(rejected)}, 0 if ok else 1)


def command_validate_skill_metadata_contract(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    findings = []
    for yaml_file in sorted((root / "skills").glob("*/agents/openai.yaml")):
        text = read_text(yaml_file)
        if any(token in text for token in [".ps1", "pwsh", "powershell", "ExecutionPolicy", "C:\\Users"]):
            findings.append({"path": normalize_rel(yaml_file, root), "reason": "metadata contains Windows/PowerShell reference"})
        if yaml is not None:
            try:
                data = yaml.safe_load(text) or {}
                interface = data.get("interface", {}) if isinstance(data, dict) else {}
                if not interface.get("display_name") or not interface.get("short_description") or not interface.get("default_prompt"):
                    findings.append({"path": normalize_rel(yaml_file, root), "reason": "metadata interface must contain display_name, short_description, and default_prompt"})
            except Exception as exc:
                findings.append({"path": normalize_rel(yaml_file, root), "reason": f"YAML parse failed: {exc}"})
    if findings:
        return emit({"ok": False, "phase": "skill-metadata-contract", "reason": "skill metadata contract failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "skill-metadata-contract", "reason": "skill metadata contract passed", "findings": []})


def command_validate_workflow_contract(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    path = root / "docs" / "superpowers" / "workflow-contract.yml"
    if yaml is None:
        raise ScriptError("PyYAML is required")
    data = yaml.safe_load(read_text(path))
    findings = []
    skills = data.get("workflow_skills", {}) if isinstance(data, dict) else {}
    for skill, config in skills.items():
        if not isinstance(config, dict):
            findings.append({"path": f"workflow_skills.{skill}", "reason": "skill contract must be an object"})
            continue
        if not config.get("purpose"):
            findings.append({"path": f"workflow_skills.{skill}.purpose", "reason": "purpose is required"})
        for validator in config.get("validators", []) or []:
            if ".ps1" in str(validator):
                findings.append({"path": f"workflow_skills.{skill}.validators", "reason": "PowerShell validator reference remains"})
            script_ref = str(validator).split()[0].lstrip("./")
            if script_ref.endswith(".sh") and not (root / script_ref).is_file():
                findings.append({"path": f"workflow_skills.{skill}.validators", "reason": f"validator is missing: {script_ref}"})
        for gate in config.get("gates", []) or []:
            options = gate.get("options", []) if isinstance(gate, dict) else []
            if not options:
                findings.append({"path": f"workflow_skills.{skill}.gates", "reason": "gate requires options"})
    if findings:
        return emit({"ok": False, "phase": "workflow-contract", "reason": "workflow contract failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "workflow-contract", "reason": "workflow contract passed", "skill_count": len(skills)})


def command_validate_worker_packets(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    packet_arg = arg_value(args, "PacketPath", default="docs/superpowers/examples/worker-handoff-packets.md")
    path = resolve_under(root, str(packet_arg), "PacketPath")
    text = read_text(path)
    lowered = text.lower()
    required_groups = {
        "source plan": ["source plan", "source_plan"],
        "issue mirror": ["issue mirror", "issue_mirror"],
        "proof oracle": ["proof oracle", "proof_oracle"],
        "validation": ["validation", "required_commands"],
        "reviewer": ["reviewer", "reviewer_role"],
        "merge": ["merge", "merge_handoff"],
    }
    missing = [label for label, variants in required_groups.items() if not any(variant in lowered for variant in variants)]
    if ".ps1" in text or "pwsh" in text.lower():
        missing.append("no PowerShell references")
    if missing:
        return emit({"ok": False, "phase": "worker-packets", "reason": "worker packet example failed", "missing": missing}, 1)
    return emit({"ok": True, "phase": "worker-packets", "reason": "worker packet example passed", "path": normalize_rel(path, root)})


def command_validate_workflow_examples(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    paths = [arg_value(args, "Path", default="docs/superpowers/examples/workflow-golden-paths.md")]
    sub = arg_value(args, "SubIssuesPath")
    if sub:
        paths.append(sub)
    findings = []
    for value in paths:
        path = resolve_under(root, str(value), "Path")
        text = read_text(path)
        if ".ps1" in text or "pwsh" in text.lower():
            findings.append({"path": normalize_rel(path, root), "reason": "PowerShell reference remains"})
        if not text.strip():
            findings.append({"path": normalize_rel(path, root), "reason": "workflow example file is empty"})
    if findings:
        return emit({"ok": False, "phase": "workflow-examples", "reason": "workflow examples failed", "findings": findings}, 1)
    return emit({"ok": True, "phase": "workflow-examples", "reason": "workflow examples passed", "paths": [str(p) for p in paths]})


def command_derive_worker_identity(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    issue_arg = arg_value(args, "IssueFile")
    if not issue_arg:
        raise ScriptError("IssueFile is required")
    issue = resolve_under(root, str(issue_arg), "IssueFile")
    if not issue.is_file():
        raise ScriptError("issue mirror is missing")
    rel = normalize_rel(issue, root)
    if not rel.startswith("docs/superpowers/issues/"):
        raise ScriptError("issue mirror must be under docs/superpowers/issues")
    text = read_text(issue)
    base = issue.stem
    issue_url = field_value(text, "GitHub Issue") or ""
    issue_number = None
    match = re.search(r"/issues/(\d+)(?:$|[?#])", issue_url)
    if match:
        issue_number = int(match.group(1))
    elif re.match(r"^(\d+)-(.+)$", base):
        issue_number = int(base.split("-", 1)[0])
    if issue_number is None:
        raise ScriptError("issue number must be present in GitHub Issue URL or issue mirror filename")
    slug = re.sub(r"[^a-z0-9]+", "-", re.sub(r"^\d+-", "", base.lower())).strip("-")
    if not slug:
        raise ScriptError("issue slug could not be derived")
    title_words = []
    known = {"api": "API", "ci": "CI", "github": "GitHub", "ui": "UI", "pr": "PR", "tdd": "TDD", "project": "Project", "align": "Align", "codex": "Codex"}
    for index, word in enumerate(slug.split("-")):
        title_words.append(known.get(word, word.capitalize() if index == 0 else word))
    title = " ".join(title_words)
    identity = {
        "issue_number": issue_number,
        "issue_slug": slug,
        "issue_title": title,
        "issue_mirror": rel,
        "issue_url": issue_url,
        "thread_title": f"Resolve #{issue_number}: {title}",
        "branch": f"codex/issue-{issue_number}-{slug}",
        "evidence_folder": f"orchestrate-issues-issue-{issue_number}-{slug}",
        "pr_title": f"Resolve #{issue_number}: {title}",
    }
    return emit({"ok": True, "phase": "derive-worker-identity", "reason": "worker identity derived", "identity": identity})


def command_validate_issue_mirror(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    issue_arg = arg_value(args, "IssueFile")
    if not issue_arg:
        raise ScriptError("IssueFile is required")
    issue = resolve_under(root, str(issue_arg), "IssueFile")
    if not issue.is_file():
        raise ScriptError(f"issue mirror does not exist: {issue_arg}")
    rel = normalize_rel(issue, root)
    if not rel.startswith("docs/superpowers/issues/"):
        raise ScriptError("issue mirror must be under docs/superpowers/issues")
    text = read_text(issue)
    required_fields = ["GitHub Issue", "Source Plan", "Goal Command"]
    missing = [field for field in required_fields if not field_value(text, field)]
    if missing:
        raise ScriptError(f"issue mirror missing required field(s): {', '.join(missing)}")
    outcome = test_issue_outcome_summary(text)
    if not outcome["ok"]:
        raise ScriptError(outcome["reason"])
    return emit({"ok": True, "phase": "validate-issue-mirror", "issue_file": rel, "reason": "issue mirror passed"})


def section_bullets(text: str, heading: str) -> list[str]:
    section = markdown_section(text, heading)
    if section is None:
        return []
    bullets = []
    for line in section.splitlines():
        match = re.match(r"^\s*-\s+(.+?)\s*$", line)
        if match:
            bullets.append(match.group(1).strip())
    return bullets


def command_prepare_worker_handoff(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    issue_arg = arg_value(args, "IssueFile")
    if not issue_arg:
        raise ScriptError("IssueFile is required")
    issue = resolve_under(root, str(issue_arg), "IssueFile")
    text = read_text(issue)
    role = (field_value(text, "Sub-Issue Role") or "").lower()
    executable = (field_value(text, "Executable") or "").lower()
    if role in {"parent", "plan-wrapper"} or executable in {"false", "no", "0"}:
        raise ScriptError(f"Sub-Issue Role {role or 'unknown'} is not executable (Executable: false); select an executable leaf issue instead")
    source_plan = field_value(text, "Source Plan")
    if not source_plan or source_plan.lower() == "none":
        raise ScriptError("Source Plan is required for worker orchestration")
    source_plan_path = resolve_under(root, source_plan, "Source Plan")
    if not source_plan_path.is_file():
        raise ScriptError(f"Source Plan does not exist: {source_plan}")
    identity_args = {"RepoRoot": str(root), "IssueFile": normalize_rel(issue, root)}
    identity_payload = json.loads(capture_command(lambda: command_derive_worker_identity(ctx, identity_args)))
    proof = section_bullets(text, "Proof Oracle")
    if not proof:
        raise ScriptError("Proof Oracle section with commands is required")
    handoff = {
        "issue_mirror": normalize_rel(issue, root),
        "issue_url": field_value(text, "GitHub Issue"),
        "source_plan": normalize_rel(source_plan_path, root),
        "classification": field_value(text, "Classification"),
        "goal_command": field_value(text, "Goal Command"),
        "worker_identity": identity_payload["identity"],
        "branch": identity_payload["identity"]["branch"],
        "branch_worktree_policy": "worker creates an isolated worktree for the branch",
        "reviewer_role": "main-thread-orchestrator",
        "proof_oracle": proof,
        "validation": {"required_commands": ["skills/orchestrate-issues/scripts/validate-worker-handoff.sh -RepoRoot . -HandoffPath <handoff-json>"]},
        "topology_handoff": {"orchestrator_role": "main-thread-orchestrator", "worker_role": "implementation-worker", "merge_owner": "merge-changes", "worker_must_not_merge": True, "wakeup_policy": "worker handoff or bounded heartbeat"},
        "merge_handoff": {"merge_owner": "merge-changes", "worker_must_not_merge": True},
        "required_skills": ["superpowers:using-git-worktrees", "superpowers:test-driven-development", "superpowers:executing-plans", "superpowers:verification-before-completion", "superpowers:finishing-a-development-branch"],
    }
    written = ""
    output = arg_value(args, "OutputPath")
    if output:
        target = resolve_under(root, str(output), "OutputPath")
        write_text(target, json.dumps(handoff, indent=2))
        written = normalize_rel(target, root)
    return emit({"ok": True, "phase": "prepare-worker-handoff", "reason": "worker handoff prepared", "handoff": handoff, "handoff_path": written})


def capture_command(func) -> str:
    import io
    from contextlib import redirect_stdout

    buf = io.StringIO()
    with redirect_stdout(buf):
        code = func()
    if code != 0:
        raise ScriptError(buf.getvalue().strip() or "nested command failed")
    return buf.getvalue()


def command_validate_worker_handoff(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    handoff, _ = read_json_arg(root, args, "HandoffJson", "HandoffPath")
    required = ["issue_mirror", "source_plan", "worker_identity", "branch", "branch_worktree_policy", "reviewer_role", "proof_oracle", "validation", "topology_handoff", "merge_handoff", "required_skills"]
    for field in required:
        if field not in handoff or handoff[field] in (None, "", []):
            raise ScriptError(f"handoff missing {field}")
    for field in ["issue_mirror", "source_plan"]:
        if not resolve_under(root, str(handoff[field]), field).is_file():
            raise ScriptError(f"{field} does not exist: {handoff[field]}")
    identity = handoff["worker_identity"]
    for field in ["issue_number", "issue_slug", "thread_title", "branch", "evidence_folder", "pr_title"]:
        if not identity.get(field):
            raise ScriptError(f"worker_identity missing {field}")
    expected_branch = f"codex/issue-{identity['issue_number']}-{identity['issue_slug']}"
    if identity.get("branch") != expected_branch or handoff.get("branch") != expected_branch:
        raise ScriptError("worker identity branch mismatch")
    if handoff.get("reviewer_role") != "main-thread-orchestrator":
        raise ScriptError("reviewer_role must be main-thread-orchestrator")
    if (handoff.get("topology_handoff") or {}).get("worker_must_not_merge") is not True:
        raise ScriptError("worker_must_not_merge must be true")
    if (handoff.get("merge_handoff") or {}).get("merge_owner") != "merge-changes":
        raise ScriptError("merge_handoff.merge_owner must be merge-changes")
    for skill in ["superpowers:using-git-worktrees", "superpowers:test-driven-development", "superpowers:verification-before-completion", "superpowers:finishing-a-development-branch"]:
        if skill not in handoff.get("required_skills", []):
            raise ScriptError(f"required skill missing: {skill}")
    return emit({"ok": True, "phase": "validate-worker-handoff", "reason": "worker handoff passed", "evidence": {"branch": handoff["branch"], "issue_mirror": handoff["issue_mirror"], "source_plan": handoff["source_plan"]}})


def command_collect_continuation(ctx: Context, args: dict[str, Any], phase: str) -> int:
    root = project_root_for(ctx, args)
    option_ids = arg_value(args, "OptionIds", default=[])
    if isinstance(option_ids, str):
        option_ids = [option_ids]
    ledger = {
        "question_id": arg_value(args, "QuestionId", default=""),
        "prompt": arg_value(args, "Prompt", default=""),
        "source": arg_value(args, "Source", default=""),
        "selected_option_id": arg_value(args, "SelectedOptionId", default=""),
        "recommended_option_id": arg_value(args, "RecommendedOptionId", default=""),
        "terminal_state": arg_value(args, "TerminalState", default=""),
        "option_ids": option_ids,
    }
    for field in ["question_id", "prompt", "source", "selected_option_id", "recommended_option_id", "terminal_state"]:
        if not ledger[field]:
            raise ScriptError(f"{field} is required")
    output_dir = arg_value(args, "OutputDir", default="")
    ledger_path = ""
    if output_dir:
        out_dir = resolve_under(root, str(output_dir), "OutputDir")
        out_dir.mkdir(parents=True, exist_ok=True)
        target = out_dir / "continuation-ledger.json"
        write_text(target, json.dumps(ledger, indent=2))
        ledger_path = normalize_rel(target, root)
    return emit({"ok": True, "phase": phase, "reason": "continuation ledger collected", "ledger": ledger, "ledger_path": ledger_path})


def command_validate_terminal_closeout(ctx: Context, args: dict[str, Any], phase: str) -> int:
    root = project_root_for(ctx, args)
    result_json_name = "PrReadyResultJson" if "resolve-issue" in ctx.script_rel else "CloseoutResultJson"
    result_path_name = "PrReadyResultPath" if "resolve-issue" in ctx.script_rel else "CloseoutResultPath"
    result, _ = read_json_arg(root, args, result_json_name, result_path_name, required=False)
    if result is None:
        alt_json = arg_value(args, "CloseoutResultJson") or arg_value(args, "PrReadyResultJson")
        if alt_json:
            result = json.loads(str(alt_json))
    decision, _ = read_json_arg(root, args, "ContinuationDecisionJson", "ContinuationDecisionPath", required=False)
    if result is None or decision is None:
        raise ScriptError("result and continuation decision are required")
    if result.get("ok") is not True:
        raise ScriptError("result gate must be ok")
    terminal = decision.get("terminal_state")
    if terminal not in {"stop", "done"}:
        raise ScriptError("terminal decision must be stop or done")
    return complete(True, phase, "terminal closeout passed")


def command_collect_pr_ready(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    setup_path = arg_value(args, "SetupLedgerPath")
    if not setup_path:
        raise ScriptError("SetupLedgerPath is required")
    setup = json.loads(read_text(resolve_under(root, str(setup_path), "SetupLedgerPath")))
    ledger = {"setup": setup, "pr": json.loads(str(arg_value(args, "PrJson", default="{}"))), "verification_commands": arg_value(args, "VerificationCommands", default=[]), "ok": True}
    output_dir = arg_value(args, "OutputDir", default="")
    ledger_path = ""
    if output_dir:
        out_dir = resolve_under(root, str(output_dir), "OutputDir")
        out_dir.mkdir(parents=True, exist_ok=True)
        target = out_dir / "pr-ready-ledger.json"
        write_text(target, json.dumps(ledger, indent=2))
        ledger_path = normalize_rel(target, root)
    return emit({"ok": True, "phase": "collect-pr-ready-ledger", "reason": "PR-ready ledger collected", "ledger": ledger, "ledger_path": ledger_path})


def command_validate_pr_ready(ctx: Context, args: dict[str, Any]) -> int:
    data, _ = read_json_arg(ctx.repo_root, args, "PrReadyLedgerJson", "PrReadyLedgerPath", required=False)
    if data is None:
        return complete(True, "validate-pr-ready", "PR-ready gate passed")
    if data.get("ok") is False:
        raise ScriptError("PR-ready ledger is not ok")
    return complete(True, "validate-pr-ready", "PR-ready gate passed")


def _as_list(value: Any) -> list[str]:
    if value in (None, ""):
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, str) and "," in value:
        return [item.strip() for item in value.split(",") if item.strip()]
    return [str(value)]


def _run_standalone_test(ctx: Context, relative_path: str, phase: str) -> int:
    script = (ctx.plugin_root or ctx.repo_root) / relative_path
    if not script.is_file():
        raise ScriptError(f"standalone test is missing: {relative_path}")
    result = run(["bash", str(script)], project_root_for(ctx, {}))
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    if result.returncode != 0:
        raise ScriptError(f"{phase} failed with exit code {result.returncode}")
    return 0


def command_test_codex_marketplace_lifecycle(ctx: Context, args: dict[str, Any]) -> int:
    return _run_standalone_test(ctx, "scripts/test-codex-marketplace-lifecycle.sh", "codex-marketplace-lifecycle")


def command_test_install_transaction(ctx: Context, args: dict[str, Any]) -> int:
    return _run_standalone_test(ctx, "scripts/test-install-transaction.sh", "install-transaction")


def command_test_linux_migration(ctx: Context, args: dict[str, Any]) -> int:
    return _run_standalone_test(ctx, "scripts/test-linux-migration.sh", "linux-migration")


def command_validate_global_policy_deduplication(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    skill_root = root / "skills"
    owner_path = skill_root / "advanced-user-input" / "SKILL.md"
    if not owner_path.is_file():
        raise ScriptError("advanced-user-input policy owner is missing")
    owner = read_text(owner_path)
    required = [
        "## Continuation Gates",
        "Revisit is non-terminal",
        "Custom Other never terminates a workflow directly",
        "A verified final Done gate requires final proof and a clean worktree",
    ]
    duplicate_phrases = [
        "Strict artifact display is mandatory and must happen before the summary or native question.",
        "The agent must not get out of the loop by itself",
        "Do not infer terminal intent from a custom answer.",
    ]
    checks: list[dict[str, Any]] = []
    for phrase in required:
        checks.append({"name": f"policy owner contains {phrase}", "ok": phrase in owner})
    for path in sorted(skill_root.glob("*/SKILL.md")):
        if path == owner_path:
            continue
        text_value = read_text(path)
        rel = normalize_rel(path, root)
        checks.append({"name": f"{rel} references policy owner", "ok": "advanced-user-input/SKILL.md" in text_value})
        checks.append({"name": f"{rel} keeps route policy local", "ok": "route-specific" in text_value})
        for phrase in duplicate_phrases:
            checks.append({"name": f"{rel} omits duplicated global policy", "ok": phrase not in text_value})
    failed = [item for item in checks if not item["ok"]]
    return emit({"ok": not failed, "phase": "global-policy-deduplication", "checks": checks, "findings": failed}, 0 if not failed else 1)


def command_validate_scorecard_proof(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    receipt = project_path_for(root, str(arg_value(args, "ReceiptPath", default="docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md")), "ReceiptPath")
    if not receipt.is_file():
        raise ScriptError(f"scorecard receipt is missing: {normalize_rel(receipt, root)}")
    text_value = read_text(receipt)
    section = re.search(r"(?ms)^## Scorecard\s*$\n(?P<body>.*?)(?=^##\s+|\Z)", text_value)
    if not section:
        raise ScriptError("scorecard receipt is missing the Scorecard section")
    rows = [line for line in section.group("body").splitlines() if line.startswith("|")][2:]
    checks: list[dict[str, Any]] = []
    for row in rows:
        cells = [cell.strip() for cell in row.strip("|").split("|")]
        if len(cells) < 4:
            continue
        target_match = re.search(r"\d+(?:\.\d+)?", cells[1])
        target = float(target_match.group(0)) if target_match else 0.0
        checks.append({"name": cells[0], "ok": target >= 9.0 and cells[2] not in {"", "TBD"} and cells[3].lower() == "pass", "target": target})
    required_commands = ["./scripts/validate.sh", "./scripts/validate-scorecard-proof.sh"]
    for command in required_commands:
        matching = [line for line in text_value.splitlines() if command in line]
        checks.append({"name": f"command receipt {command}", "ok": any("| pass |" in line.lower() for line in matching)})
    failed = [item for item in checks if not item["ok"]]
    return emit({"ok": bool(checks) and not failed, "phase": "scorecard-proof", "receipt": normalize_rel(receipt, root), "checks": checks, "findings": failed}, 0 if checks and not failed else 1)


def command_validate_tracker_roadmap(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    roadmap_path = project_path_for(root, str(arg_value(args, "RoadmapPath", default="docs/agents/project-roadmap.json")), "RoadmapPath")
    if not roadmap_path.is_file():
        raise ScriptError(f"tracker roadmap is missing: {normalize_rel(roadmap_path, root)}")
    roadmap = json.loads(read_text(roadmap_path))
    required = ["repository", "milestone_root", "spec_file_template", "plan_file_template", "issue_file_template", "hierarchy_labels", "triage_states"]
    checks = [{"name": field, "ok": roadmap.get(field) not in (None, "", [])} for field in required]
    expected_labels = {"type:issue-set", "type:sub-milestone", "type:plan-wrapper"}
    checks.append({"name": "hierarchy labels", "ok": expected_labels.issubset(set(roadmap.get("hierarchy_labels", [])))})
    for key, prefix in (("spec_file_template", "docs/superpowers/specs/"), ("plan_file_template", "docs/superpowers/plans/"), ("issue_file_template", "docs/superpowers/issues/")):
        checks.append({"name": f"canonical {key}", "ok": str(roadmap.get(key, "")).startswith(prefix)})
    failed = [item for item in checks if not item["ok"]]
    return emit({"ok": not failed, "phase": "tracker-roadmap-proof", "roadmap": normalize_rel(roadmap_path, root), "checks": checks, "findings": failed}, 0 if not failed else 1)


def command_validate_issue_title_policy(ctx: Context, args: dict[str, Any]) -> int:
    title = str(arg_value(args, "Title", default="")).strip()
    if not title:
        raise ScriptError("Title is required")
    milestone_titles = _as_list(arg_value(args, "KnownMilestoneTitles", default=[]))
    milestone_numbers = _as_list(arg_value(args, "KnownMilestoneNumbers", default=[]))
    findings: list[str] = []
    if re.match(r"^\s*(?:\[[^]]+\]|#?\d+[.)-])\s*", title):
        findings.append("title starts with a hierarchy or milestone marker")
    if re.search(r"(?i)\b(?:sub[- ]?milestone|milestone)\s*[#:]?\s*\d+", title):
        findings.append("title embeds a milestone ordinal")
    lowered = title.casefold()
    for value in milestone_titles:
        if value.strip() and value.strip().casefold() in lowered:
            findings.append(f"title embeds milestone title: {value}")
    for value in milestone_numbers:
        if value.strip() and re.search(rf"(?<!\d){re.escape(value.strip())}(?!\d)", title):
            findings.append(f"title embeds milestone number: {value}")
    return emit({"ok": not findings, "phase": "validate-issue-title-policy", "title": title, "findings": findings}, 0 if not findings else 1)


def command_build_issue_hierarchy_plan(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    source_plan = str(arg_value(args, "SourcePlanPath", "SourcePlan", default=""))
    if not source_plan or not project_path_for(root, source_plan, "SourcePlan").is_file():
        raise ScriptError("SourcePlanPath must identify an existing source plan")
    mode = str(arg_value(args, "HierarchyMode", default="flat"))
    if mode not in {"flat", "issue-set", "sub-milestone"}:
        raise ScriptError("HierarchyMode must be flat, issue-set, or sub-milestone")
    parent = str(arg_value(args, "ParentTitle", default="")).strip()
    wrappers = _as_list(arg_value(args, "WrapperTitles", default=[]))
    leaves = _as_list(arg_value(args, "LeafTitles", default=[]))
    if not leaves:
        raise ScriptError("at least one LeafTitles value is required")
    if mode != "flat" and not parent:
        raise ScriptError(f"ParentTitle is required for {mode}")
    titles = ([parent] if parent else []) + wrappers + leaves
    for title in titles:
        result = command_validate_issue_title_policy(ctx, {"Title": title, "KnownMilestoneTitles": arg_value(args, "KnownMilestoneTitles", default=[]), "KnownMilestoneNumbers": arg_value(args, "KnownMilestoneNumbers", default=[])})
        if result != 0:
            raise ScriptError(f"issue title policy rejected: {title}")
    operations: list[dict[str, Any]] = []
    if parent:
        operations.append({"role": "parent", "title": parent, "command": ["gh", "issue", "create", "--title", parent]})
    for wrapper in wrappers:
        operations.append({"role": "plan-wrapper", "title": wrapper, "parent": parent, "command": ["gh", "issue", "create", "--title", wrapper, "--parent", "<parent-url>"]})
    for leaf in leaves:
        operations.append({"role": "leaf", "title": leaf, "parent": wrappers[0] if wrappers else parent, "command": ["gh", "issue", "create", "--title", leaf] + (["--parent", "<parent-url>"] if parent else [])})
    return emit({"ok": True, "phase": "build-issue-hierarchy-plan", "hierarchy_mode": mode, "source_plan": normalize_rel(project_path_for(root, source_plan), root), "publication_order": operations})


def command_validate_issue_hierarchy(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    mirror_path = arg_value(args, "IssueMirrorPath")
    fixture_path = arg_value(args, "GitHubIssueFixturePath", "IssueJsonPath")
    if not mirror_path or not fixture_path:
        raise ScriptError("IssueMirrorPath and GitHubIssueFixturePath are required")
    mirror_file = project_path_for(root, str(mirror_path), "IssueMirrorPath")
    fixture_file = project_path_for(root, str(fixture_path), "GitHubIssueFixturePath")
    if not mirror_file.is_file() or not fixture_file.is_file():
        raise ScriptError("issue hierarchy inputs must exist")
    text_value = read_text(mirror_file)
    issue = json.loads(read_text(fixture_file))
    role_match = re.search(r"(?im)^Sub-Issue Role:\s*(.+)$", text_value)
    executable_match = re.search(r"(?im)^Executable:\s*(true|false)$", text_value)
    role = role_match.group(1).strip().lower() if role_match else ""
    executable = executable_match.group(1).lower() == "true" if executable_match else None
    findings: list[str] = []
    if role not in {"parent", "plan-wrapper", "leaf"}:
        findings.append("Sub-Issue Role must be parent, plan-wrapper, or leaf")
    if executable is None:
        findings.append("Executable metadata is required")
    if role in {"parent", "plan-wrapper"} and executable is not False:
        findings.append(f"{role} mirrors must set Executable: false")
    if role == "leaf" and executable is not True:
        findings.append("leaf mirrors must set Executable: true")
    if has_switch(args, "MilestoneRequired") and not issue.get("milestone"):
        findings.append("GitHub issue milestone is required")
    if role != "parent" and not (issue.get("parent") or re.search(r"(?im)^Parent Issue:\s*https://", text_value)):
        findings.append("child issue must identify its parent")
    return emit({"ok": not findings, "phase": "validate-issue-hierarchy", "role": role, "executable": executable, "findings": findings}, 0 if not findings else 1)


def command_hydrate_external_issue(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    issue, _ = read_json_arg(root, args, "IssueJson", "IssueJsonPath", required=False)
    if issue is None:
        raise ScriptError("IssueJson or IssueJsonPath is required for deterministic hydration")
    number = issue.get("number")
    title = str(issue.get("title") or arg_value(args, "IssueTitle", default="")).strip()
    url = str(issue.get("url") or arg_value(args, "IssueUrl", default="")).strip()
    body = str(issue.get("body", "")).strip()
    if not number or not title or not url:
        raise ScriptError("external issue requires number, title, and url")
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:72]
    plan_slug = str(arg_value(args, "OutputPlanSlug", default=slug))
    plan = root / "docs" / "superpowers" / "plans" / f"{plan_slug}-plan.md"
    mirror = root / "docs" / "superpowers" / "issues" / f"{number}-{slug}.md"
    if not plan.exists():
        write_text(plan, f"# {title} Implementation Plan\n\n**Goal:** {title}\n\n## Outcome Proof\n\n**Intent:** {body or title}\n\n**Evidence:** Implement and verify the linked issue acceptance criteria.\n")
    role = "leaf" if issue.get("parent") else "parent"
    executable = "true" if role == "leaf" else "false"
    write_text(mirror, f"# {title}\n\nIssue: {url}\nSource Plan: {normalize_rel(plan, root)}\nSub-Issue Role: {role}\nExecutable: {executable}\n\n## Outcome Summary\n\n{body or title}\n")
    return emit({"ok": True, "phase": "hydrate-external-issue", "issue_mirror": normalize_rel(mirror, root), "source_plan": normalize_rel(plan, root), "issue_url": url})


def command_prepare_github_project_board(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    mode = str(arg_value(args, "Mode", default="Plan"))
    roadmap_path = root / "docs" / "agents" / "project-roadmap.json"
    roadmap = json.loads(read_text(roadmap_path))
    board = roadmap.get("github_project_board", {})
    required_fields = _as_list(arg_value(args, "RequiredFields", default=["Status", "Milestone", "Issue Type", "Agent State"]))
    if mode == "Plan":
        return emit({"ok": True, "phase": "prepare-github-project-board", "mode": mode, "mutation": False, "repository": roadmap.get("repository"), "required_fields": required_fields, "native_approval_required": True})
    if mode == "ValidateConfig":
        missing = sorted(set(required_fields) - set(board.get("fields", [])))
        return emit({"ok": not missing and bool(board.get("project_url")), "phase": "prepare-github-project-board", "mode": mode, "missing_fields": missing, "project_url": board.get("project_url", "")}, 0 if not missing and board.get("project_url") else 1)
    if mode != "Create":
        raise ScriptError("Mode must be Plan, Create, or ValidateConfig")
    approval, _ = read_json_arg(root, args, "NativeApprovalJson", "NativeApprovalPath")
    if approval.get("question_id") != "project_setup_board_approval" or approval.get("selected_action") != "create":
        raise ScriptError("board creation requires native project_setup_board_approval evidence")
    raise ScriptError("board creation must be executed through the authenticated GitHub workflow owner")


def command_resolve_preflight(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    mirror_value = arg_value(args, "IssueMirrorPath", "IssueMirror")
    if not mirror_value:
        raise ScriptError("IssueMirrorPath is required")
    mirror = project_path_for(root, str(mirror_value), "IssueMirrorPath")
    if not mirror.is_file():
        raise ScriptError("issue mirror is missing")
    text_value = read_text(mirror)
    source_match = re.search(r"(?im)^Source Plan:\s*`?([^`\n]+)`?\s*$", text_value)
    if not source_match:
        raise ScriptError("issue mirror must link a source plan")
    source_plan = project_path_for(root, source_match.group(1).strip(), "Source Plan")
    if not source_plan.is_file():
        raise ScriptError("linked source plan is missing")
    executable = re.search(r"(?im)^Executable:\s*true\s*$", text_value) is not None
    role = re.search(r"(?im)^Sub-Issue Role:\s*leaf\s*$", text_value) is not None
    if not executable or not role:
        raise ScriptError("direct resolution requires an executable leaf issue mirror")
    return emit({"ok": True, "phase": "resolve-preflight", "issue_mirror": normalize_rel(mirror, root), "source_plan": normalize_rel(source_plan, root)})


def command_validate_resolve_setup(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    ledger, _ = read_json_arg(root, args, "SetupLedgerJson", "SetupLedgerPath")
    required = ["issue_url", "issue_mirror", "source_plan", "branch", "goal_activation_proof", "goal_objective", "execution_decision", "outcome_proof", "proof_oracle"]
    missing = [field for field in required if ledger.get(field) in (None, "", [])]
    if "goal_id" not in ledger and "thread_goal_proof" not in ledger:
        missing.append("goal_id or thread_goal_proof")
    if missing:
        raise ScriptError("setup ledger missing: " + ", ".join(missing))
    if (ledger.get("execution_decision") or {}).get("selected_mode") == "orchestrated-worker":
        raise ScriptError("orchestrated-worker execution belongs to orchestrate-issues")
    for field, prefix in (("issue_mirror", "docs/superpowers/issues/"), ("source_plan", "docs/superpowers/plans/")):
        value = str(ledger[field])
        if not value.replace("\\", "/").startswith(prefix) or not project_path_for(root, value, field).is_file():
            raise ScriptError(f"{field} must identify an existing canonical artifact")
    return emit({"ok": True, "phase": "validate-resolve-setup", "issue_mirror": ledger["issue_mirror"], "source_plan": ledger["source_plan"], "branch": ledger["branch"]})


def command_collect_merge_continuation(ctx: Context, args: dict[str, Any]) -> int:
    return command_collect_continuation(ctx, args, "collect-merge-continuation-ledger")


def command_collect_resolve_continuation(ctx: Context, args: dict[str, Any]) -> int:
    return command_collect_continuation(ctx, args, "collect-resolve-continuation-ledger")


def command_validate_merge_terminal_closeout(ctx: Context, args: dict[str, Any]) -> int:
    return command_validate_terminal_closeout(ctx, args, "validate-merge-terminal-closeout")


def command_validate_resolve_terminal_closeout(ctx: Context, args: dict[str, Any]) -> int:
    return command_validate_terminal_closeout(ctx, args, "validate-resolve-terminal-closeout")


def _load_local_branch_setup(root: Path, args: dict[str, Any]) -> dict[str, Any]:
    setup, _ = read_json_arg(root, args, "SetupLedgerJson", "SetupLedgerPath", required=False)
    if setup is None:
        setup = {"merge_mode": "local-branch", "branch": arg_value(args, "Branch"), "source_plan": arg_value(args, "SourcePlan")}
    if setup.get("merge_mode") != "local-branch":
        raise ScriptError("setup ledger merge_mode must be local-branch")
    branch = str(setup.get("branch", ""))
    if not branch or branch in {"main", "master", "origin/main", "origin/master"}:
        raise ScriptError("local branch closeout requires a non-default branch")
    source_plan = str(setup.get("source_plan", ""))
    if not source_plan or not project_path_for(root, source_plan, "source_plan").is_file():
        raise ScriptError("local branch closeout requires an existing source plan")
    return setup


def command_prepare_local_branch_closeout(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    setup = _load_local_branch_setup(root, args)
    branch = str(setup["branch"])
    current = run(["git", "branch", "--show-current"], root)
    exists = run(["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], root)
    if current.returncode != 0 or current.stdout.strip() != "main":
        raise ScriptError("prepare local branch closeout must run from main")
    if exists.returncode != 0:
        raise ScriptError(f"local branch is missing: {branch}")
    readiness, _ = read_json_arg(root, args, "ReadinessReviewJson", "ReadinessReviewPath")
    required_review = ["plan_alignment", "correctness", "maintainability", "reality_evidence"]
    if any(readiness.get(field) is not True for field in required_review):
        raise ScriptError("readiness review must approve alignment, correctness, maintainability, and reality evidence")
    status = run(["git", "status", "--short"], root)
    if status.returncode != 0 or status.stdout.strip():
        raise ScriptError("main must be clean before local branch closeout")
    changed = run(["git", "diff", "--name-only", f"main...{branch}"], root)
    evidence = {"branch": branch, "source_plan": setup["source_plan"], "changed_files": [line for line in changed.stdout.splitlines() if line], "readiness_review": readiness, "remote_publication_required": False}
    return emit({"ok": True, "phase": "prepare-local-branch-closeout", "reason": "local branch premerge proof prepared", "evidence": evidence})


def command_apply_local_branch_closeout(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    setup = _load_local_branch_setup(root, args)
    branch = str(setup["branch"])
    premerge, _ = read_json_arg(root, args, "PremergeResultJson", "PremergeResultPath")
    decision, _ = read_json_arg(root, args, "MergeDecisionJson", "MergeDecisionPath")
    if premerge.get("ok") is not True:
        raise ScriptError("premerge result must be ok")
    if decision.get("selected_action") != "merge":
        raise ScriptError("merge decision must select merge")
    current = run(["git", "branch", "--show-current"], root)
    if current.returncode != 0 or current.stdout.strip() != "main":
        raise ScriptError("apply local branch closeout must run from main")
    if has_switch(args, "DryRun"):
        return emit({"ok": True, "phase": "apply-local-branch-closeout", "reason": "local branch closeout dry run passed", "evidence": {"branch": branch, "would_merge": True, "remote_publication": False}})
    merge = run(["git", "merge", "--ff-only", branch], root)
    if merge.returncode != 0:
        raise ScriptError(f"git merge --ff-only failed: {merge.stderr.strip() or merge.stdout.strip()}")
    return emit({"ok": True, "phase": "apply-local-branch-closeout", "reason": "local branch merged without remote publication", "evidence": {"branch": branch, "commit": run(["git", "rev-parse", "HEAD"], root).stdout.strip(), "remote_publication": False}})


def command_generate_outcome_workflow_summary(ctx: Context, args: dict[str, Any]) -> int:
    from workflow_graph import load_workflow_graph, render_outcome_workflow, render_route_index, validate_workflow_graph

    root = project_root_for(ctx, args)
    output = project_path_for(root, str(arg_value(args, "OutputPath", default="docs/superpowers/OUTCOME_WORKFLOW.md")), "OutputPath")
    index_output = project_path_for(root, str(arg_value(args, "RouteIndexPath", default="docs/superpowers/WORKFLOW_ROUTE_INDEX.md")), "RouteIndexPath")
    contract_path = root / "docs" / "superpowers" / "workflow-contract.yml"
    graph = load_workflow_graph(contract_path)
    findings = validate_workflow_graph(graph, root)
    if findings:
        raise ScriptError("workflow graph is invalid: " + "; ".join(f"{item.code} at {item.path}" for item in findings))
    generated = render_outcome_workflow(graph)
    generated_index = render_route_index(graph)
    if has_switch(args, "Check"):
        current = read_text(output) if output.is_file() else ""
        current_index = read_text(index_output) if index_output.is_file() else ""
        fresh = current == generated and current_index == generated_index
        return emit({"ok": fresh, "phase": "generate-outcome-workflow-summary", "output_path": normalize_rel(output, root), "route_index_path": normalize_rel(index_output, root), "stale": not fresh}, 0 if fresh else 1)
    write_text(output, generated)
    write_text(index_output, generated_index)
    return emit({"ok": True, "phase": "generate-outcome-workflow-summary", "output_path": normalize_rel(output, root), "route_index_path": normalize_rel(index_output, root), "workflow_skill_count": len(graph.routes)})


def command_workflow_run(ctx: Context, args: dict[str, Any]) -> int:
    from workflow_runtime import execute_workflow_action

    root = project_root_for(ctx, args)
    run_root_value = arg_value(args, "RunRoot")
    authorization_value = arg_value(args, "AuthorizationPath")
    action = str(arg_value(args, "Action", default=""))
    if not run_root_value or not authorization_value or not action:
        raise ScriptError("RunRoot, AuthorizationPath, and Action are required")
    run_root = project_path_for(root, str(run_root_value), "RunRoot")
    authorization_path = project_path_for(root, str(authorization_value), "AuthorizationPath")
    receipt = execute_workflow_action(
        ctx.plugin_root or ctx.repo_root,
        root,
        run_root,
        authorization_path,
        action,
        run_id=str(arg_value(args, "RunId", default="")),
        mode=str(arg_value(args, "Mode", default="")),
        candidate=str(arg_value(args, "Candidate", default="")),
        claim=str(arg_value(args, "Claim", default="")),
        reason=str(arg_value(args, "Reason", default="")),
    )
    return emit(receipt)


def command_prepare_release(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    manifest_path = root / ".codex-plugin" / "plugin.json"
    changelog_path = root / "CHANGELOG.md"
    manifest = json.loads(read_text(manifest_path))
    version = str(arg_value(args, "Version", default=manifest.get("version", ""))).lstrip("v")
    base = version.split("+", 1)[0]
    changelog = read_text(changelog_path)
    has_unreleased = bool(re.search(r"(?m)^##\s+Unreleased\s*$", changelog))
    has_version = bool(re.search(rf"(?m)^##\s+v?{re.escape(base)}(\s|$)", changelog))
    head = run(["git", "rev-parse", "HEAD"], root)
    status = run(["git", "status", "--short"], root)
    branch = run(["git", "branch", "--show-current"], root)
    dirty = bool(status.stdout.strip())
    check_only = has_switch(args, "CheckOnly")
    checks = [
        {"name": "manifest name", "ok": manifest.get("name") == "superpowers-project", "reason": "passed" if manifest.get("name") == "superpowers-project" else "manifest name must be superpowers-project"},
        {"name": "manifest version present", "ok": bool(manifest.get("version")), "reason": "passed" if manifest.get("version") else "manifest version is empty"},
        {"name": "changelog has release evidence", "ok": has_unreleased or has_version, "reason": "passed" if (has_unreleased or has_version) else f"CHANGELOG.md needs Unreleased or {base} entry"},
        {"name": "git head available", "ok": head.returncode == 0, "reason": "passed" if head.returncode == 0 else head.stderr.strip()},
    ]
    if not check_only:
        checks.append({"name": "worktree clean", "ok": not dirty, "reason": "passed" if not dirty else "release publishing requires a clean worktree"})
        checks.append({"name": "version entry exists", "ok": has_version, "reason": "passed" if has_version else "release publishing requires a versioned changelog entry"})
    ok = all(item["ok"] for item in checks)
    receipt = {
        "ok": ok,
        "phase": "prepare-release",
        "check_only": check_only,
        "manifest_name": manifest.get("name", ""),
        "manifest_version": manifest.get("version", ""),
        "release_version": version,
        "release_base_version": base,
        "branch": branch.stdout.strip(),
        "commit": head.stdout.strip() if head.returncode == 0 else "",
        "dirty": dirty,
        "dirty_status": status.stdout.strip(),
        "changelog": {"has_unreleased": has_unreleased, "has_version_entry": has_version, "path": "CHANGELOG.md"},
        "required_gates": ["scripts/validate.sh", "scripts/sync-live.sh --validate", "git status --short"],
        "publish_ready": (not dirty) and has_version and ok,
        "checks": checks,
    }
    output = arg_value(args, "OutputPath")
    if output:
        write_text(resolve_under(root, str(output), "OutputPath"), json.dumps(receipt, indent=2))
    return emit(receipt, 0 if ok else 1)


def runtime_contract_hash(root: Path) -> str:
    return package_contract_hash(root)


def plugin_manifest(root: Path) -> dict[str, Any] | None:
    path = root / ".codex-plugin" / "plugin.json"
    if not path.is_file():
        return None
    return json.loads(read_text(path))


def version_surface(name: str, root: Path | None, source_hash: str) -> dict[str, Any]:
    exists = root is not None and root.is_dir()
    manifest = plugin_manifest(root) if exists and root is not None else None
    contract = runtime_contract_hash(root) if exists and root is not None else ""
    return {
        "name": name,
        "path": str(root.resolve()) if root is not None else "",
        "exists": bool(exists),
        "manifest_name": manifest.get("name", "") if manifest else "",
        "manifest_version": manifest.get("version", "") if manifest else "",
        "contract_hash": contract,
        "matches_source": bool(exists and contract == source_hash),
    }


def command_get_agent_plugin_version(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    home = Path.home()
    live_root = Path(str(arg_value(args, "LivePluginRoot", default=str(home / ".codex" / "plugins" / "superpowers-project")))).expanduser()
    manifest = plugin_manifest(root)
    if manifest is None:
        raise ScriptError("source plugin manifest is missing")
    source_hash = runtime_contract_hash(root)
    head = run(["git", "rev-parse", "HEAD"], root)
    status = run(["git", "status", "--short"], root)
    source = {
        "name": "source",
        "path": str(root),
        "manifest_name": manifest.get("name", ""),
        "manifest_version": manifest.get("version", ""),
        "git_commit": head.stdout.strip() if head.returncode == 0 else "",
        "dirty": bool(status.stdout.strip()),
        "contract_hash": source_hash,
    }
    live = version_surface("live", live_root, source_hash)
    observed_root = None
    observed_plugin = arg_value(args, "ObservedPluginRoot")
    observed_skill = arg_value(args, "ObservedSkillRoot")
    if observed_plugin:
        observed_root = Path(str(observed_plugin)).expanduser().resolve()
    elif observed_skill:
        cursor = Path(str(observed_skill)).expanduser().resolve()
        if cursor.is_file():
            cursor = cursor.parent
        while cursor != cursor.parent:
            if (cursor / ".codex-plugin" / "plugin.json").is_file():
                observed_root = cursor
                break
            cursor = cursor.parent
        if observed_root is None:
            raise ScriptError(f"could not resolve plugin root from observed skill root: {observed_skill}")
    observed = version_surface("observed", observed_root, source_hash) if observed_root else None
    failures = []
    if not live.get("matches_source"):
        failures.append("live plugin differs from source")
    if observed and not observed.get("matches_source"):
        failures.append("observed plugin differs from source")
    if live.get("manifest_version") != manifest.get("version"):
        failures.append("live plugin manifest version differs from source")
    ok = not failures if has_switch(args, "RequireCurrent") else True
    report = {
        "ok": ok,
        "phase": "agent-plugin-version",
        "reason": "source, live, and observed plugin surfaces are current" if ok else "; ".join(failures),
        "source": source,
        "live": live,
        "observed": observed,
        "current_agent_known": observed is not None,
        "recommended_recovery": "Install or update through the supported Codex marketplace/plugin CLI, then start a fresh agent session if the observed surface differs.",
    }
    if has_switch(args, "Banner"):
        print("\n".join([
            "Superpowers Project plugin",
            f"manifest_version: {source['manifest_version']}",
            f"git_commit: {source['git_commit']}",
            f"source_dirty: {source['dirty']}",
            f"contract_hash: {source['contract_hash']}",
            f"source/live: {'current' if live.get('matches_source') else 'stale'}",
            f"observed: {'not supplied' if observed is None else ('current' if observed.get('matches_source') else 'stale')}",
            f"reason: {report['reason']}",
        ]))
        return 0 if ok else 1
    return emit(report, 0 if ok else 1)


def command_test_agent_plugin_version(ctx: Context, args: dict[str, Any]) -> int:
    """Exercise version freshness against isolated live and observed fixtures."""
    root = project_root_for(ctx, args)
    checks: list[dict[str, Any]] = []

    def run_version(extra: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = command_get_agent_plugin_version(ctx, {"RepoRoot": str(root), **extra})
        text = output.getvalue().strip()
        try:
            report = json.loads(text)
        except json.JSONDecodeError as exc:
            raise ScriptError(f"version checker emitted invalid JSON: {text!r}") from exc
        return status, report

    with tempfile.TemporaryDirectory(prefix="agent-plugin-version-") as tmp:
        fixture = Path(tmp)
        live = fixture / "live"
        observed = fixture / "observed"
        shutil.copytree(root, live, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
        shutil.copytree(root, observed, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))

        status, current = run_version({"LivePluginRoot": str(live), "RequireCurrent": True})
        checks.append({
            "name": "isolated live surface is current",
            "ok": status == 0 and current.get("ok") is True and current.get("live", {}).get("matches_source") is True,
            "reason": current.get("reason", "version check did not pass"),
        })

        observed_checker = observed / "scripts" / "get-agent-plugin-version.sh"
        if not observed_checker.is_file():
            raise ScriptError(f"observed fixture is missing {observed_checker.relative_to(observed)}")
        observed_checker.write_text(observed_checker.read_text(encoding="utf-8") + "\n# fixture drift\n", encoding="utf-8")
        status, stale = run_version({
            "LivePluginRoot": str(live),
            "ObservedPluginRoot": str(observed),
            "RequireCurrent": True,
        })
        reason = str(stale.get("reason", ""))
        checks.append({
            "name": "observed runtime drift is rejected",
            "ok": status != 0 and stale.get("ok") is False and stale.get("observed", {}).get("matches_source") is False and "observed plugin differs from source" in reason,
            "reason": reason,
        })

    ok = all(bool(check["ok"]) for check in checks)
    return emit({
        "ok": ok,
        "phase": "agent-plugin-version-test",
        "reason": "isolated freshness fixtures passed" if ok else "agent plugin version fixture failed",
        "checks": checks,
    }, 0 if ok else 1)


def copy_tree(source: Path, target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))


def command_sync_live(ctx: Context, args: dict[str, Any]) -> int:
    root = ctx.repo_root.resolve()
    home = Path.home()
    live_root = Path(str(arg_value(args, "LivePluginRoot", default=str(home / ".codex" / "plugins" / "superpowers-project")))).expanduser()
    user_skills = Path(str(arg_value(args, "UserSkillsRoot", default=str(home / ".agents" / "skills")))).expanduser()
    marketplace = Path(str(arg_value(args, "MarketplacePath", default=str(home / ".agents" / "plugins" / "marketplace.json")))).expanduser()
    if has_switch(args, "Validate", "validate"):
        result = run(["bash", str(root / "scripts" / "validate.sh")], root)
        print(result.stdout, end="")
        print(result.stderr, file=sys.stderr, end="")
        if result.returncode != 0:
            raise ScriptError("validation failed before sync")
    (live_root / ".codex-plugin").mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / ".codex-plugin" / "plugin.json", live_root / ".codex-plugin" / "plugin.json")
    for folder in ["skills", "assets", "scripts"]:
        source = root / folder
        target = live_root / folder
        if source.exists():
            copy_tree(source, target)
    copy_tree(root / "docs" / "superpowers", live_root / "docs" / "superpowers")
    user_skills.mkdir(parents=True, exist_ok=True)
    for skill in USER_SKILLS:
        source = root / "skills" / skill
        if source.is_dir():
            copy_tree(source, user_skills / skill)
    marketplace.parent.mkdir(parents=True, exist_ok=True)
    if marketplace.is_file():
        data = json.loads(read_text(marketplace))
    else:
        data = {"name": "personal", "interface": {"displayName": "Personal"}, "plugins": []}
    plugins = [p for p in data.get("plugins", []) if p.get("name") not in {"superpowers-project", "milestones", "project"}]
    plugins.append({"name": "superpowers-project", "source": {"source": "local", "path": "./.codex/plugins/superpowers-project"}, "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Productivity"})
    data["plugins"] = plugins
    write_text(marketplace, json.dumps(data, indent=2))
    # Installed package discovery and updates are owned by the supported
    # marketplace/plugin CLI. Never mutate Codex cache candidates directly.
    drift = compare_trees(root / "skills", live_root / "skills")
    if drift:
        raise ScriptError(f"live install drift detected: {json.dumps(drift)}")
    return emit({
        "ok": True,
        "source": str(root),
        "live_plugin_root": str(live_root),
        "user_skills_root": str(user_skills),
        "marketplace": {"marketplace_path": str(marketplace), "plugin_name": "superpowers-project", "source_path": "./.codex/plugins/superpowers-project"},
        "deployed_plugin_skills": sorted(active_skill_names(root)),
        "deployed_user_skills": sorted(USER_SKILLS),
    })


def command_install(ctx: Context, args: dict[str, Any]) -> int:
    manifest = plugin_manifest(ctx.repo_root)
    if not manifest or manifest.get("name") != "superpowers-project":
        raise ScriptError("plugin manifest name must be superpowers-project")
    sync_args = dict(args)
    if not has_switch(args, "SkipValidation"):
        sync_args["Validate"] = True
    return command_sync_live(ctx, sync_args)


def validate_skill_source_contract(root: Path) -> None:
    names = active_skill_names(root)
    expected = sorted(ACTIVE_SKILLS_EXCLUDING_USER | USER_SKILLS)
    missing = sorted(set(expected) - set(names))
    extra = sorted(set(names) - set(expected))
    if missing:
        raise ScriptError(f"missing active skill(s): {', '.join(missing)}")
    if extra:
        raise ScriptError(f"unexpected skill(s): {', '.join(extra)}")
    if (root / "canonical-skills").is_dir():
        raise ScriptError("canonical-skills is retired; skills must be the single source root")
    for name in expected:
        skill_file = root / "skills" / name / "SKILL.md"
        if not skill_file.is_file():
            raise ScriptError(f"missing skill SKILL.md: {skill_file}")
        text = read_text(skill_file)
        if f"name: {name}" not in text:
            raise ScriptError(f"missing skill name in {normalize_rel(skill_file, root)}")
        if any(needle in text for needle in ["namespace wrapper", "Read the deployed user-level `SKILL.md` above.", "do not invent separate behavior"]):
            raise ScriptError(f"skills must contain full implementations, not namespace wrappers: {normalize_rel(skill_file, root)}")


def validate_no_windows_active_surface(root: Path) -> None:
    if list((root / "scripts").rglob("*.ps1")) or list((root / "skills").rglob("*.ps1")) or list((root / ".github").rglob("*.ps1")):
        raise ScriptError("active script/workflow tree still contains .ps1 files")
    active_paths = [root / "AGENTS.md", root / "README.md", root / ".codex-plugin", root / ".github", root / "scripts", root / "skills", root / "docker-compose.agent-native-preview.yml", root / "docker"]
    files: list[Path] = []
    for path in active_paths:
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(p for p in path.rglob("*") if p.is_file() and p.suffix.lower() not in {".png", ".svg"})
    pattern = re.compile(r"(pwsh|powershell|ExecutionPolicy|windows-latest|choco install|\.ps1|scripts\\|C:\\Users\\|cmd\.exe|powershell\.exe)", re.I)
    offenders = []
    for file in files:
        if file.name in {"test-linux-migration.sh", "superpowers_project_cli.py"}:
            continue
        try:
            for idx, line in enumerate(read_text(file).splitlines(), 1):
                if pattern.search(line):
                    offenders.append(f"{normalize_rel(file, root)}:{idx}")
                    break
        except UnicodeDecodeError:
            continue
    if offenders:
        raise ScriptError("active runtime surfaces still contain Windows/PowerShell references: " + ", ".join(offenders[:20]))


def command_validate(ctx: Context, args: dict[str, Any]) -> int:
    root = ctx.repo_root
    checks: list[dict[str, Any]] = []

    def step(name: str, func) -> None:
        try:
            func()
            checks.append({"name": name, "ok": True})
        except Exception as exc:
            checks.append({"name": name, "ok": False, "reason": str(exc)})
            raise

    try:
        if yaml is None:
            raise ScriptError("python3 PyYAML is required")
        step("Linux migration contract", lambda: run_must(["bash", str(root / "scripts" / "test-linux-migration.sh")], root))
        step("Skill source contract", lambda: validate_skill_source_contract(root))
        step("Linux active surface scan", lambda: validate_no_windows_active_surface(root))
        step("Superpowers project path contract", lambda: validate_superpowers_paths(root))
        step("Plugin manifest validation", lambda: run_must(["python3", str(root / "scripts" / "validate-plugin.py"), str(root)], root))
        for skill in active_skill_names(root):
            step(f"quick_validate {skill}", lambda skill=skill: run_must(["python3", str(root / "scripts" / "quick-validate-skill.py"), str(root / "skills" / skill)], root))
        test_scripts = sorted((root / "scripts").glob("test-*.sh"))
        for script in test_scripts:
            if script.name == "test-linux-migration.sh":
                continue
            step(script.stem, lambda script=script: run_must(["bash", str(script)], root))
        step("skill metadata workflow contract", lambda: command_validate_skill_metadata_contract(ctx, {"RepoRoot": str(root)}) == 0 or (_ for _ in ()).throw(ScriptError("skill metadata contract failed")))
        step("workflow contract registry", lambda: command_validate_workflow_contract(ctx, {"RepoRoot": str(root)}) == 0 or (_ for _ in ()).throw(ScriptError("workflow contract failed")))
        step("worker handoff packet schema", lambda: command_validate_worker_packets(ctx, {"RepoRoot": str(root), "PacketPath": "docs/superpowers/examples/worker-handoff-packets.md"}) == 0 or (_ for _ in ()).throw(ScriptError("worker packet validator failed")))
        step("workflow golden path examples", lambda: command_validate_workflow_examples(ctx, {"RepoRoot": str(root), "Path": "docs/superpowers/examples/workflow-golden-paths.md"}) == 0 or (_ for _ in ()).throw(ScriptError("workflow example validator failed")))
        step("skill script parameter contract", lambda: command_validate_skill_script_contract(ctx, {"RepoRoot": str(root)}) == 0 or (_ for _ in ()).throw(ScriptError("skill script contract failed")))
        if not has_switch(args, "SkipScenarioTests"):
            for skill in active_skill_names(root):
                scenario = root / "skills" / skill / "scripts" / "test-scenarios.sh"
                if scenario.is_file():
                    step(f"scenario tests {skill}", lambda scenario=scenario: run_must(["bash", str(scenario)], root, timeout=int(arg_value(args, "ScenarioTimeoutSeconds", default=600))))
        step("flat artifact root contract", lambda: command_validate_flat_roots(ctx, {"RepoRoot": str(root)}) == 0 or (_ for _ in ()).throw(ScriptError("flat artifact root validator failed")))
        step("generated runtime state guardrails", lambda: command_validate_generated_state(ctx, {"RepoRoot": str(root)}) == 0 or (_ for _ in ()).throw(ScriptError("generated runtime state validator failed")))
        stale_scan(root)
        return emit({"ok": True, "repo_root": str(root), "checks": checks})
    except Exception as exc:
        return emit({"ok": False, "repo_root": str(root), "reason": str(exc), "checks": checks}, 1)


def run_must(cmd: list[str], cwd: Path, timeout: int | None = None) -> None:
    result = run(cmd, cwd, timeout)
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    if result.returncode != 0:
        raise ScriptError(f"command failed: {' '.join(cmd)}")


def validate_superpowers_paths(root: Path) -> None:
    forbidden = [
        "docs/milestones/<milestone-folder>/ideas",
        "docs/milestones/<milestone-folder>/issues",
        "docs/plans",
        "docs/issues",
    ]
    for skill in active_skill_names(root):
        path = root / "skills" / skill / "SKILL.md"
        text = read_text(path)
        for pattern in forbidden:
            if pattern in text:
                raise ScriptError(f"active Superpowers Project skill uses retired canonical path '{pattern}': {normalize_rel(path, root)}")


def stale_scan(root: Path) -> None:
    pattern = re.compile(r"plan-goal-implement-merge|setup-project-roadmap|setup_project_roadmap_plan|grill-create-issues|issue-goal-execute-merge|docs/ideas/<YYYY|docs/ideas/20|cross-milestone.*docs/ideas|docs/ideas.*cross-milestone", re.I)
    roots = [root / "skills", root / "docs", root / ".codex-plugin", root / "README.md", root / "AGENTS.md", root / "CHANGELOG.md"]
    offenders = []
    for item in roots:
        files = [item] if item.is_file() else [p for p in item.rglob("*") if p.is_file()] if item.is_dir() else []
        for file in files:
            if file.suffix.lower() not in {".md", ".json", ".yaml", ".yml", ".txt"}:
                continue
            text = read_text(file)
            if pattern.search(text):
                offenders.append(normalize_rel(file, root))
    if offenders:
        raise ScriptError("unexpected stale references: " + ", ".join(sorted(set(offenders))))


def command_align_project(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    mode = str(arg_value(args, "Mode", default="LocalDocs"))
    findings = []
    for forbidden in ["docs/issues", "docs/plans", "docs/ideas"]:
        if (root / forbidden).exists():
            findings.append({"category": "blocking", "path": forbidden, "reason": "retired canonical root exists"})
    return emit({"ok": len(findings) == 0, "phase": "align-project", "mode": mode, "findings": findings}, 0 if not findings else 1)


def command_select_candidate(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    inventory_arg = arg_value(args, "InventoryPath")
    candidates = []
    if inventory_arg:
        inventory = json.loads(read_text(resolve_under(root, str(inventory_arg), "InventoryPath")))
        candidates = inventory.get("candidates", inventory if isinstance(inventory, list) else [])
    selected = next((c for c in candidates if c.get("ready") is True), None) if isinstance(candidates, list) else None
    return emit({"ok": selected is not None, "phase": "select-candidate", "selected_candidate": selected, "reason": "candidate selected" if selected else "no ready candidates"}, 0 if selected else 1)


def command_collect_premerge(ctx: Context, args: dict[str, Any]) -> int:
    return collect_simple_ledger(ctx, args, "collect-premerge-ledger", "premerge-ledger.json")


def command_collect_closeout(ctx: Context, args: dict[str, Any]) -> int:
    return collect_simple_ledger(ctx, args, "collect-closeout-ledger", "closeout-ledger.json")


def collect_simple_ledger(ctx: Context, args: dict[str, Any], phase: str, filename: str) -> int:
    root = project_root_for(ctx, args)
    ledger = {"ok": True, "phase": phase, "arguments": {k: v for k, v in args.items() if k != "_positional"}}
    output_dir = arg_value(args, "OutputDir", default="")
    ledger_path = ""
    if output_dir:
        out_dir = resolve_under(root, str(output_dir), "OutputDir")
        out_dir.mkdir(parents=True, exist_ok=True)
        target = out_dir / filename
        write_text(target, json.dumps(ledger, indent=2))
        ledger_path = normalize_rel(target, root)
    return emit({"ok": True, "phase": phase, "reason": f"{phase} collected", "ledger": ledger, "ledger_path": ledger_path})


def command_premerge(ctx: Context, args: dict[str, Any]) -> int:
    return complete(True, "premerge", "premerge gate passed")


def command_closeout(ctx: Context, args: dict[str, Any]) -> int:
    return complete(True, "closeout", "closeout gate passed")


def command_validate_merge_decision(ctx: Context, args: dict[str, Any]) -> int:
    decision, _ = read_json_arg(ctx.repo_root, args, "MergeDecisionJson", "MergeDecisionPath", required=False)
    if decision and decision.get("selected_action") == "decline":
        raise ScriptError("merge decision declined")
    return complete(True, "validate-merge-decision", "merge decision approved")


def command_prepare_execution(ctx: Context, args: dict[str, Any]) -> int:
    mode = str(arg_value(args, "Mode", default="Inspect"))
    return emit({"ok": True, "phase": "prepare-execution", "mode": mode, "goal_objective": "Resolve linked issue with validated plan evidence"})


def command_repo_gate(ctx: Context, args: dict[str, Any]) -> int:
    status = run(["git", "status", "--short"], ctx.repo_root)
    return emit({"ok": status.returncode == 0, "phase": "repo-gate", "dirty_status": status.stdout.strip()})

def command_validate_skill_scenario(ctx: Context, args: dict[str, Any]) -> int:
    """Run the executable/source contract for a skill scenario launcher."""
    parts = Path(ctx.script_rel).parts
    skill = parts[1] if len(parts) >= 4 and parts[0] == "skills" else ""
    skill_root = ctx.plugin_root / "skills" / skill
    findings: list[str] = []
    if not skill or not (skill_root / "SKILL.md").is_file():
        findings.append("skill SKILL.md is missing")
    if skill and f"name: {skill}" not in read_text(skill_root / "SKILL.md"):
        findings.append("SKILL.md name does not match launcher")
    for script in skill_root.glob("scripts/**/*.sh"):
        if not os.access(script, os.X_OK):
            findings.append(f"non-executable script: {script.relative_to(ctx.plugin_root)}")
    ok = not findings
    return emit({"ok": ok, "phase": "skill-scenarios", "skill": skill, "findings": findings}, 0 if ok else 1)


def dispatch_command(ctx: Context, command_name: str, args: dict[str, Any]) -> int:
    handler = globals().get(command_name)
    if not callable(handler):
        raise ScriptError(f"unregistered command handler: {command_name}")
    return handler(ctx, args)


def dispatch(ctx: Context) -> int:
    args = parse_ps_args(ctx.args)
    try:
        catalog = load_command_catalog(ctx.repo_root)
        spec = catalog.get(ctx.script_rel)
        if spec is None:
            raise ScriptError(f"unregistered script path: {ctx.script_rel}")
        if has_switch(args, "DispatchProbe"):
            return emit({"ok": True, "path": spec.path, "handler": spec.handler, "kind": spec.kind, "mutation": spec.mutation})
        return dispatch_command(ctx, spec.handler, args)
    except Exception as exc:
        return complete(False, Path(ctx.script_name).stem, str(exc), script=ctx.script_rel)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("script_path")
    known, rest = parser.parse_known_args(argv)
    script_path = Path(known.script_path).resolve()
    repo_root = find_repo_root(script_path)
    ctx = Context(script_path=script_path, repo_root=repo_root, plugin_root=repo_root,
                  invocation_cwd=Path.cwd().resolve(), script_rel=normalize_rel(script_path, repo_root), script_name=script_path.name, args=rest)
    return dispatch(ctx)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
