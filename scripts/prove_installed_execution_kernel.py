#!/usr/bin/env python3
"""Prove an installed snapshot exposes the same fail-closed execution kernel."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess

from scripts.lib.package_provenance import runtime_contract_hash
from tests.execution_kernel_fixtures import envelope, make_repo, remove_repo


def _run(launcher: Path, repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["bash", str(launcher), "-RepoRoot", str(repo), *args], cwd=repo, text=True, capture_output=True, check=False)


def prove_installed_execution_kernel(source_root: Path, installed_root: Path) -> dict[str, object]:
    source_root = source_root.resolve()
    installed_root = installed_root.resolve()
    source_hash = runtime_contract_hash(source_root)
    installed_hash = runtime_contract_hash(installed_root)
    if source_hash != installed_hash:
        raise RuntimeError("installed package differs from source")
    launcher = installed_root / "skills/resolve-issue/scripts/validate-pr-ready.sh"
    repo = make_repo()
    try:
        missing = _run(launcher, repo)
        missing_payload = json.loads(missing.stdout)
        if missing.returncode == 0 or missing_payload.get("error", {}).get("code") != "evidence_missing":
            raise RuntimeError("installed launcher did not fail closed without evidence")
        fixture = envelope(repo, "pr_ready")
        valid = _run(launcher, repo, "-EvidenceEnvelopeJson", json.dumps(fixture, separators=(",", ":")))
        if valid.returncode != 0:
            raise RuntimeError(valid.stderr or valid.stdout or "installed valid fixture failed")
        payload = json.loads(valid.stdout)
        receipt = payload["receipt"]
        return {
            "source_package_hash": source_hash,
            "installed_package_hash": installed_hash,
            "negative_error_code": missing_payload["error"]["code"],
            "validator_id": receipt["validator_id"],
            "envelope_hash": receipt["envelope_hash"],
            "receipt_hash": receipt["receipt_hash"],
        }
    finally:
        remove_repo(repo)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--installed-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prove_installed_execution_kernel(args.source_root, args.installed_root), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
