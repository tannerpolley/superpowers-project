#!/usr/bin/env python3
"""Validate the executable workflow graph for duplicate or malformed gates."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

import yaml


def findings_for(path: Path) -> list[str]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    findings: list[str] = []
    skills = data.get("workflow_skills")
    if not isinstance(skills, dict) or not skills:
        return ["workflow_skills must be a non-empty mapping"]
    seen: dict[str, str] = {}
    for skill, config in skills.items():
        if not isinstance(config, dict):
            findings.append(f"{skill}: configuration must be a mapping")
            continue
        for key in ("purpose", "validators"):
            if not config.get(key):
                findings.append(f"{skill}: missing {key}")
        if skill != "companion-interface" and not config.get("gates"):
            findings.append(f"{skill}: missing gates")
        top_level = config.get("top_level_options", []) or []
        if any(not isinstance(option, str) for option in top_level):
            findings.append(f"{skill}: top_level_options must contain string labels")
        for index, gate in enumerate(config.get("gates", []) or []):
            if not isinstance(gate, dict):
                findings.append(f"{skill}.gates[{index}]: gate must be a mapping")
                continue
            question_id = gate.get("question_id")
            if not isinstance(question_id, str) or not question_id.strip():
                findings.append(f"{skill}.gates[{index}]: question_id must be a string")
            elif question_id not in seen:
                seen[question_id] = skill
            options = gate.get("options", [])
            if not isinstance(options, list) or not options or any(
                not isinstance(option, str) and not (isinstance(option, dict) and isinstance(option.get("label"), str))
                for option in options
            ):
                findings.append(f"{skill}.gates[{index}]: options must contain string labels")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default="docs/superpowers/workflow-contract.yml")
    args = parser.parse_args()
    findings = findings_for(Path(args.path))
    if findings:
        print("workflow graph invalid:")
        print("\n".join(f"- {finding}" for finding in findings))
        return 1
    print("workflow graph valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
