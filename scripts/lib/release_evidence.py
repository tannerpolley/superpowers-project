"""Reproducible release evidence and base-tag rules."""
from __future__ import annotations

import re
from pathlib import Path


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
