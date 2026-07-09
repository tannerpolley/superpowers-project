"""Deterministic provenance for the installable plugin surface."""
from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True)
class PackageEntry:
    path: str
    mode: int
    length: int
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


_ROOTS = (".codex-plugin", "skills", "assets", "scripts", "docs/superpowers")
_CONTRACT_NAMES = {"workflow-contract.yml", "loop-mode-contract.yml"}


def _included(path: Path, root: Path) -> bool:
    rel = path.relative_to(root).as_posix()
    if any(part in {"__pycache__", ".git"} for part in path.parts):
        return False
    if path.suffix in {".pyc", ".pyo"}:
        return False
    return rel.startswith(_ROOTS)


def _files(root: Path) -> Iterable[Path]:
    for rel in _ROOTS:
        base = root / rel
        if base.is_file() and _included(base, root):
            yield base
        elif base.is_dir():
            yield from (p for p in base.rglob("*") if p.is_file() and _included(p, root))


def runtime_manifest(plugin_root: Path) -> list[PackageEntry]:
    root = Path(plugin_root).resolve()
    entries: list[PackageEntry] = []
    for path in sorted(_files(root), key=lambda p: p.relative_to(root).as_posix()):
        data = path.read_bytes()
        entries.append(PackageEntry(
            path=path.relative_to(root).as_posix(),
            mode=path.stat().st_mode & 0o777,
            length=len(data),
            sha256=hashlib.sha256(data).hexdigest(),
        ))
    return entries


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

