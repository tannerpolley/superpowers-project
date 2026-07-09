#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from skill_slimming import load_capabilities, validate_skill_slimming


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=str(Path(__file__).resolve().parents[1]))
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    contract = load_capabilities(root / "docs" / "superpowers" / "capabilities.yml")
    findings, metrics = validate_skill_slimming(root, contract)
    print(json.dumps({"ok": not findings, "phase": "skill-slimming", "metrics": metrics, "findings": findings}, indent=2))
    return 0 if not findings else 1


if __name__ == "__main__":
    raise SystemExit(main())
