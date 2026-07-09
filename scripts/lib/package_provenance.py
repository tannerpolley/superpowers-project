"""Deterministic provenance for the installable plugin surface."""
from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
import os
import fnmatch
from pathlib import Path
from typing import Any, Iterable

import yaml


@dataclass(frozen=True)
class PackageEntry:
    path: str
    mode: int
    length: int
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class RuntimePackage:
    version: int
    include: tuple[str, ...]


def load_runtime_package(plugin_root: Path) -> RuntimePackage:
    root = Path(plugin_root).resolve()
    path = root / ".codex-plugin" / "runtime-package.yml"
    if not path.is_file():
        raise ValueError("runtime package manifest is missing")
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    patterns = data.get("include")
    if data.get("version") != 1 or not isinstance(patterns, list) or not patterns or any(not isinstance(item, str) or not item.strip() for item in patterns):
        raise ValueError("runtime package manifest requires version 1 and non-empty include patterns")
    return RuntimePackage(version=1, include=tuple(patterns))


def _included(path: Path, root: Path, package: RuntimePackage) -> bool:
    rel = path.relative_to(root).as_posix()
    if any(part in {"__pycache__", ".git"} for part in path.parts):
        return False
    if path.suffix in {".pyc", ".pyo"}:
        return False
    return any(fnmatch.fnmatchcase(rel, pattern) for pattern in package.include)


def _files(root: Path, package: RuntimePackage) -> Iterable[Path]:
    yield from (path for path in root.rglob("*") if path.is_file() and _included(path, root, package))


def runtime_manifest(plugin_root: Path) -> list[PackageEntry]:
    root = Path(plugin_root).resolve()
    package = load_runtime_package(root)
    entries: list[PackageEntry] = []
    for path in sorted(_files(root, package), key=lambda p: p.relative_to(root).as_posix()):
        data = path.read_bytes()
        entries.append(PackageEntry(
            path=path.relative_to(root).as_posix(),
            mode=path.stat().st_mode & 0o777,
            length=len(data),
            sha256=hashlib.sha256(data).hexdigest(),
        ))
    return entries


def validate_runtime_reads(plugin_root: Path, package: RuntimePackage | None = None) -> list[str]:
    root = Path(plugin_root).resolve()
    selected = package or load_runtime_package(root)
    included = {path.relative_to(root).as_posix() for path in _files(root, selected)}
    required = {
        ".codex-plugin/plugin.json",
        ".codex-plugin/runtime-package.yml",
        "docs/superpowers/workflow-contract.yml",
        "docs/superpowers/loop-mode-contract.yml",
        "docs/superpowers/governance-profiles.yml",
        "docs/superpowers/capabilities.yml",
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/OUTCOME_WORKFLOW.md",
        "docs/superpowers/WORKFLOW_ROUTE_INDEX.md",
        "docs/superpowers/backlog/ACTIVE.md",
        "docs/superpowers/examples/workflow-golden-paths.md",
        "docs/superpowers/examples/worker-handoff-packets.md",
        "docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md",
    }
    for source_root in (root / "scripts", root / "skills"):
        for path in source_root.rglob("*") if source_root.is_dir() else []:
            if not path.is_file() or path.suffix.lower() not in {".py", ".md", ".yaml", ".yml"}:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for match in __import__("re").finditer(r"docs/superpowers/[A-Za-z0-9_./-]+\.(?:md|ya?ml)", text):
                rel = match.group(0)
                if (root / rel).is_file():
                    required.add(rel)
    return [f"runtime read is excluded from package: {path}" for path in sorted(required - included)]


def runtime_contract_hash(plugin_root: Path) -> str:
    payload = [entry.to_dict() for entry in runtime_manifest(plugin_root)]
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def verify_runtime_provenance(ledger: dict[str, Any], plugin_root: Path, project_root: Path) -> None:
    expected = [entry.to_dict() for entry in runtime_manifest(plugin_root)]
    supplied = ledger.get("manifest")
    if supplied != expected:
        raise ValueError("runtime provenance manifest does not match plugin package")
    actual_hash = runtime_contract_hash(plugin_root)
    if ledger.get("contract_hash") != actual_hash:
        raise ValueError("runtime provenance contract hash does not match plugin package")
    expected_project = str(Path(project_root).resolve())
    supplied_project = ledger.get("project_root")
    if supplied_project is None or str(Path(str(supplied_project)).resolve()) != expected_project:
        raise ValueError("runtime provenance project root does not match invocation")
