"""Reproducible release evidence and base-tag rules."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Mapping


class ReleaseEvidenceError(ValueError):
    pass


def validate_dependency_pins(path: Path) -> list[str]:
    findings = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        if "==" not in value or any(operator in value for operator in (">=", "<=", "~=", "!=")):
            findings.append(f"line {number} is not exactly pinned: {value}")
    return findings


def base_release_tag(version: str) -> str:
    base = version.split("+", 1)[0]
    if re.fullmatch(r"\d+\.\d+\.\d+", base) is None:
        raise ReleaseEvidenceError("release version must have a numeric major.minor.patch base")
    return f"v{base}"


def validate_release_evidence(evidence: Mapping[str, Any]) -> None:
    commit = evidence.get("commit")
    package_hash = evidence.get("package_hash")
    version = evidence.get("manifest_version")
    if not commit or not package_hash or not version:
        raise ReleaseEvidenceError("release evidence requires commit, package hash, and manifest version")
    for gate in ("validation", "sync", "cleanup"):
        receipt = evidence.get(gate) or {}
        if receipt.get("ok") is not True or receipt.get("commit") != commit or receipt.get("package_hash") != package_hash:
            raise ReleaseEvidenceError(f"{gate} proof is missing or stale")
    installation = evidence.get("installation") or {}
    if installation.get("ok") is not True or installation.get("commit") != commit or installation.get("package_hash") != package_hash or installation.get("manifest_version") != version:
        raise ReleaseEvidenceError("installation proof is missing or stale")
    trials = evidence.get("agent_trials") or {}
    if trials.get("ok") is not True or trials.get("package_hash") != package_hash:
        raise ReleaseEvidenceError("agent trial proof is missing or stale")
