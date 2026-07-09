"""Typed workflow graph loading, validation, and deterministic rendering."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class Finding:
    code: str
    path: str
    message: str


@dataclass(frozen=True)
class WorkflowGraph:
    version: int
    helpers: dict[str, Any]
    routes: dict[str, dict[str, Any]]
    source_path: Path


def load_workflow_graph(path: Path) -> WorkflowGraph:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    routes = data.get("workflow_skills")
    if not isinstance(routes, dict):
        routes = {}
    return WorkflowGraph(
        version=int(data.get("version", 0)),
        helpers=data.get("helpers") if isinstance(data.get("helpers"), dict) else {},
        routes=routes,
        source_path=path,
    )


def _labels(options: Any) -> list[Any]:
    if not isinstance(options, list):
        return []
    return [option.get("label") if isinstance(option, dict) else option for option in options]


def validate_workflow_graph(graph: WorkflowGraph, root: Path) -> list[Finding]:
    findings: list[Finding] = []
    if not graph.routes:
        return [Finding("missing-routes", "workflow_skills", "workflow_skills must be a non-empty mapping")]
    owners: dict[str, str] = {}
    questions: dict[str, str] = {}
    entrypoints: list[str] = []
    for route_name, route in graph.routes.items():
        path = f"workflow_skills.{route_name}"
        if not isinstance(route, dict):
            findings.append(Finding("invalid-route", path, "route must be a mapping"))
            continue
        owner = route.get("owner")
        if not isinstance(owner, str) or not owner.strip():
            findings.append(Finding("missing-owner", f"{path}.owner", "route owner is required"))
        elif owner in owners:
            findings.append(Finding("duplicate-owner", f"{path}.owner", f"owner also controls {owners[owner]}"))
        else:
            owners[owner] = route_name
        if route.get("entrypoint") is True:
            entrypoints.append(route_name)
        for field, code in (("artifacts", "missing-artifacts"), ("validators", "missing-validators"), ("next_routes", "missing-transitions")):
            if not isinstance(route.get(field), list) or not route.get(field):
                findings.append(Finding(code, f"{path}.{field}", f"{field} must be a non-empty list"))
        gates = route.get("gates")
        if not isinstance(gates, list) or (route_name != "companion-interface" and not gates):
            findings.append(Finding("missing-gates", f"{path}.gates", "route gates are required"))
            gates = []
        allowed_parents = set(_labels(route.get("top_level_options", [])))
        for nested in route.get("nested_routes", []) or []:
            if isinstance(nested, dict):
                allowed_parents.update(_labels(nested.get("options", [])))
                allowed_parents.add(nested.get("parent_option"))
        allowed_parents.update(route.get("external_parents", []) or [])
        allowed_parents.add(True)
        for index, gate in enumerate(gates):
            gate_path = f"{path}.gates[{index}]"
            if not isinstance(gate, dict):
                findings.append(Finding("invalid-gate", gate_path, "gate must be a mapping"))
                continue
            question_id = gate.get("question_id")
            if not isinstance(question_id, str) or not question_id.strip():
                findings.append(Finding("missing-question-id", f"{gate_path}.question_id", "question_id must be text"))
            elif question_id in questions:
                findings.append(Finding("duplicate-question-id", f"{gate_path}.question_id", f"{question_id} is also owned by {questions[question_id]}"))
            else:
                questions[question_id] = route_name
            options = gate.get("options")
            labels = _labels(options)
            if not labels or any(not isinstance(label, str) for label in labels):
                findings.append(Finding("boolean-label", f"{gate_path}.options", "option labels must be non-empty strings"))
            parent = gate.get("parent_option")
            if parent is not None and parent not in allowed_parents:
                findings.append(Finding("wrong-parent", f"{gate_path}.parent_option", f"parent option is not declared by route {route_name}"))
            gate_type = gate.get("gate_type")
            if gate_type == "final_health" and labels != ["Done", "Revisit", "Stop"]:
                findings.append(Finding("illegal-terminal", f"{gate_path}.options", "final health options must be Done, Revisit, Stop"))
            if gate_type == "top_level_continuation" and labels != ["Yes", "Revisit", "Stop"]:
                findings.append(Finding("illegal-terminal", f"{gate_path}.options", "top-level options must be Yes, Revisit, Stop"))
            if gate_type not in {"final_health", "top_level_continuation"} and gate.get("allow_terminal_options") is not True and any(label in {"Done", "Stop"} for label in labels):
                findings.append(Finding("illegal-terminal", f"{gate_path}.options", "nested and data-selection gates cannot terminate directly"))
        for target in route.get("next_routes", []) or []:
            if target not in graph.routes:
                findings.append(Finding("missing-transition-target", f"{path}.next_routes", f"unknown route: {target}"))
    if len(entrypoints) != 1:
        findings.append(Finding("entrypoint-count", "workflow_skills", "exactly one route must set entrypoint: true"))
    elif entrypoints:
        reachable: set[str] = set()
        pending = [entrypoints[0]]
        while pending:
            current = pending.pop()
            if current in reachable or current not in graph.routes:
                continue
            reachable.add(current)
            pending.extend(graph.routes[current].get("next_routes", []) or [])
        for route_name in sorted(set(graph.routes) - reachable):
            findings.append(Finding("unreachable-route", f"workflow_skills.{route_name}", f"route is unreachable from {entrypoints[0]}"))
    return sorted(findings, key=lambda item: (item.path, item.code, item.message))


def render_outcome_workflow(graph: WorkflowGraph) -> str:
    lines = [
        "# Superpowers Project Outcome Workflow",
        "",
        "> Generated from `docs/superpowers/workflow-contract.yml` by `scripts/generate-outcome-workflow-summary.sh`. Do not edit by hand.",
        "",
        "## Contract",
        "",
        "- Plugin: `superpowers-project`",
        "- Prompt namespace: `$superpowers-project:*`",
        "- Workflow entrypoint: `$superpowers-project:initiate-workflow`",
        "- Global continuation policy owner: `$superpowers-project:advanced-user-input`",
        "- Runtime evidence: immutable authorization plus replayed `.superpowers/runs/<run-id>/events.jsonl`",
        "",
        "## Routes",
        "",
        "| Route | Purpose | Artifacts | Validators | Next routes |",
        "|---|---|---|---|---|",
    ]
    for name, route in graph.routes.items():
        artifacts = "<br>".join(f"`{value}`" for value in route.get("artifacts", [])) or "None"
        validators = "<br>".join(f"`{value}`" for value in route.get("validators", [])) or "None"
        next_routes = "<br>".join(f"`{value}`" for value in route.get("next_routes", [])) or "None"
        lines.append(f"| `{name}` | {route.get('purpose', '')} | {artifacts} | {validators} | {next_routes} |")
    lines.extend([
        "",
        "## Completion Scope",
        "",
        "- `candidate`: the selected candidate has acceptance and verifier proof.",
        "- `route`: the one authorized Auto route has closed with acceptance and verifier proof.",
        "- `iteration`: the Looping candidate has acceptance, verifier, and budget evidence.",
        "- `project`: reserved for explicit final health proof; route completion never implies project completion.",
        "",
        "## Required Local Gates",
        "",
        "- `./scripts/validate-workflow-graph.py`",
        "- `./scripts/generate-outcome-workflow-summary.sh -Check`",
        "- `./scripts/validate.sh`",
        "- `./scripts/sync-live.sh --validate` after committed installable changes",
        "",
    ])
    return "\n".join(lines)


def render_route_index(graph: WorkflowGraph) -> str:
    lines = [
        "# Workflow Route Index",
        "",
        "> Generated from `docs/superpowers/workflow-contract.yml`. Do not edit by hand.",
        "",
    ]
    for name, route in graph.routes.items():
        lines.extend([f"## `$superpowers-project:{name}`", "", route.get("purpose", ""), "", f"Owner: `{route.get('owner', '')}`", "", "Gates:"])
        for gate in route.get("gates", []) or []:
            labels = ", ".join(str(label) for label in _labels(gate.get("options", [])))
            lines.append(f"- `{gate.get('question_id', '')}` ({gate.get('gate_type', '')}): {labels}")
        lines.extend(["", "Next routes: " + (", ".join(f"`{value}`" for value in route.get("next_routes", [])) or "None"), ""])
    return "\n".join(lines)
