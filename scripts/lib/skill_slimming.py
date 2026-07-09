"""Capability and prompt-size contract for Superpowers Project route skills."""
from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


def load_capabilities(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(value.get("capabilities"), dict) or not isinstance(value.get("routes"), dict):
        raise ValueError("capability contract requires capabilities and routes mappings")
    known = set(value["capabilities"])
    for route, config in value["routes"].items():
        declared = set(config.get("required", [])) | set(config.get("optional", []))
        unknown = sorted(declared - known)
        if unknown:
            raise ValueError(f"{route} declares unknown capabilities: {', '.join(unknown)}")
    return value


def validate_route_capabilities(route: str, available: list[str], contract: dict[str, Any]) -> None:
    config = contract["routes"].get(route)
    if config is None:
        raise ValueError(f"capability route is missing: {route}")
    missing = [name for name in config.get("required", []) if name not in set(available)]
    if missing:
        raise ValueError("missing required capabilities: " + ", ".join(missing))


def validate_skill_slimming(root: Path, contract: dict[str, Any]) -> tuple[list[dict[str, str]], dict[str, Any]]:
    findings: list[dict[str, str]] = []
    duplicate_phrases = [
        "The agent must not get out of the loop by itself",
        "Do not infer terminal intent from a custom answer.",
        "Strict artifact display is mandatory and must happen before the summary or native question.",
    ]
    route_lines = 0
    routes = contract["routes"]
    for route, config in routes.items():
        skill_path = root / "skills" / route / "SKILL.md"
        metadata_path = root / "skills" / route / "agents" / "openai.yaml"
        if not skill_path.is_file() or not metadata_path.is_file():
            findings.append({"code": "missing-route-files", "route": route})
            continue
        text = skill_path.read_text(encoding="utf-8")
        route_lines += len(text.splitlines())
        if "## Capability Preflight" not in text:
            findings.append({"code": "missing-capability-preflight", "route": route})
        if "skills/advanced-user-input/SKILL.md" not in text or "route-specific" not in text:
            findings.append({"code": "missing-global-policy-reference", "route": route})
        for phrase in duplicate_phrases:
            if phrase in text:
                findings.append({"code": "duplicated-global-policy", "route": route})
        for pairing in config.get("method_pairings", []):
            if pairing not in text:
                findings.append({"code": "missing-method-pairing", "route": route, "pairing": pairing})
        metadata = yaml.safe_load(metadata_path.read_text(encoding="utf-8")) or {}
        declared = set((metadata.get("interface") or {}).get("capabilities") or [])
        required = set(config.get("required", []))
        if not required.issubset(declared):
            findings.append({"code": "missing-capability-declaration", "route": route, "missing": ",".join(sorted(required - declared))})
    baseline = int(contract["baseline_route_lines"])
    target = int(baseline * (1 - float(contract["target_reduction_percent"]) / 100))
    reduction = round((baseline - route_lines) * 100 / baseline, 1)
    if route_lines > target:
        findings.append({"code": "skill-size-target", "route": "all", "actual": str(route_lines), "target": str(target)})
    metrics = {"baseline_route_lines": baseline, "route_lines": route_lines, "target_route_lines": target, "reduction_percent": reduction}
    return findings, metrics
