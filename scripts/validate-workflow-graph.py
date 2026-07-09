#!/usr/bin/env python3
"""Validate the authoritative typed workflow graph."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from workflow_graph import load_workflow_graph, validate_workflow_graph


def findings_for(path: Path, root: Path | None = None) -> list[str]:
    graph = load_workflow_graph(path)
    return [f"{item.code}: {item.path}: {item.message}" for item in validate_workflow_graph(graph, root or path.resolve().parents[2])]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default="docs/superpowers/workflow-contract.yml")
    args = parser.parse_args()
    path = Path(args.path).resolve()
    findings = findings_for(path)
    if findings:
        print("workflow graph invalid:")
        print("\n".join(f"- {finding}" for finding in findings))
        return 1
    print("workflow graph valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
