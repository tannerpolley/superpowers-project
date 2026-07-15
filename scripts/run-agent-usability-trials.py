#!/usr/bin/env python3
"""Run explicit Project Truss scenario fixtures with independent Codex verification."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from package_provenance import runtime_contract_hash
from run_agent_usability_trials_support import summarize_observed_events


WORKER_SCHEMA = {
    "type": "object",
    "required": ["observed_outcome", "friction", "claim"],
    "properties": {
        "observed_outcome": {"enum": ["pass", "blocked", "fail"]},
        "friction": {"type": "integer", "minimum": 1, "maximum": 5},
        "claim": {"type": "object", "required": ["summary"], "properties": {"summary": {"type": "string"}}, "additionalProperties": False},
    },
    "additionalProperties": False,
}
VERIFIER_SCHEMA = {
    "type": "object",
    "required": ["decision", "reason"],
    "properties": {"decision": {"enum": ["pass", "blocked", "reject"]}, "reason": {"type": "string"}},
    "additionalProperties": False,
}


def invoke_agent(project: Path, prompt: str, schema: Path, output: Path) -> tuple[dict, str]:
    result = subprocess.run([
        "codex", "exec", "--ephemeral", "--ignore-user-config", "--sandbox", "workspace-write",
        "--skip-git-repo-check", "-C", str(project), "--output-schema", str(schema),
        "--output-last-message", str(output), prompt,
    ], cwd=project, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Codex agent failed")
    session = re.search(r"(?m)^session id:\s*(\S+)\s*$", result.stderr)
    if session is None:
        raise RuntimeError("Codex agent completed without a session id")
    return json.loads(output.read_text(encoding="utf-8")), session.group(1)


def run_trial(plugin_root: Path, output_dir: Path, scenario_dir: Path, repetition: int, worker_schema: Path, verifier_schema: Path) -> Path:
    prompt_path = scenario_dir / "prompt.md"
    oracle_path = scenario_dir / "oracle.json"
    if not prompt_path.is_file() or not oracle_path.is_file():
        raise ValueError(f"scenario requires prompt.md and oracle.json: {scenario_dir}")
    oracle = json.loads(oracle_path.read_text(encoding="utf-8"))
    scenario = str(oracle.get("scenario") or scenario_dir.name)
    expected = str(oracle.get("expected_outcome") or "")
    if expected not in {"pass", "blocked"}:
        raise ValueError(f"scenario expected_outcome must be pass or blocked: {scenario_dir}")
    trial_root = output_dir / "runs" / f"{scenario}-{repetition}"
    if trial_root.exists():
        shutil.rmtree(trial_root)
    fixture = scenario_dir / "fixture"
    project = trial_root / "project"
    shutil.copytree(fixture, project) if fixture.is_dir() else project.mkdir(parents=True)
    prompt = prompt_path.read_text(encoding="utf-8") + f"\n\nUse the Project Truss source at {plugin_root}. Return only the requested JSON."
    worker, worker_id = invoke_agent(project, prompt, worker_schema, trial_root / "worker-output.json")
    verifier_prompt = f"Independently verify repository {project} against untouched oracle {oracle_path}. Do not trust the worker narrative. Return the oracle outcome only when current repository evidence supports it; otherwise return reject."
    verifier, verifier_id = invoke_agent(project, verifier_prompt, verifier_schema, trial_root / "verifier-output.json")
    observed_events = [{"kind": "tool_call", "name": "worker", "session_id": worker_id}, {"kind": "tool_call", "name": "verifier", "session_id": verifier_id}]
    metrics = summarize_observed_events(observed_events)
    evidence = []
    for path in sorted(item for item in project.rglob("*") if item.is_file() and ".git" not in item.parts):
        evidence.append({"path": path.relative_to(project).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    receipt = {
        "schema_version": 1, "trial_id": f"{scenario}-{repetition}", "scenario": scenario, "repetition": repetition,
        "worker": {"id": worker_id}, "verifier": {"id": verifier_id}, "package_hash": runtime_contract_hash(plugin_root),
        "oracle_sha256": hashlib.sha256(oracle_path.read_bytes()).hexdigest(), "trial_root": str(trial_root), "project_root": str(project),
        "expected_outcome": expected, "observed_outcome": worker["observed_outcome"], "friction": worker["friction"],
        "user_input_calls": 0, "external_mutations": metrics["external_mutations"], "repository_evidence": evidence,
        "worker_claim": worker["claim"], "verifier_decision": verifier["decision"],
    }
    receipt_path = trial_root / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--scenario-dir", action="append", required=True)
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--parallelism", type=int, default=1)
    args = parser.parse_args()
    if not args.execute:
        parser.error("--execute is required because this command starts fresh Codex agents")
    if shutil.which("codex") is None:
        parser.error("codex CLI is required")
    if not 1 <= args.parallelism <= 4 or args.repetitions < 1:
        parser.error("parallelism must be 1-4 and repetitions must be positive")
    plugin_root = Path(__file__).resolve().parents[1]
    output_dir = Path(args.output_dir).resolve()
    try:
        output_dir.relative_to(plugin_root)
    except ValueError:
        parser.error("--output-dir must be inside the Project Truss source root")
    output_dir.mkdir(parents=True, exist_ok=True)
    worker_schema = output_dir / "worker-output.schema.json"
    verifier_schema = output_dir / "verifier-output.schema.json"
    worker_schema.write_text(json.dumps(WORKER_SCHEMA), encoding="utf-8")
    verifier_schema.write_text(json.dumps(VERIFIER_SCHEMA), encoding="utf-8")
    jobs = [(Path(directory).resolve(), repetition) for directory in args.scenario_dir for repetition in range(1, args.repetitions + 1)]
    with ThreadPoolExecutor(max_workers=args.parallelism) as executor:
        receipts = list(executor.map(lambda item: run_trial(plugin_root, output_dir, item[0], item[1], worker_schema, verifier_schema), jobs))
    relative = [path.relative_to(plugin_root).as_posix() if path.is_relative_to(plugin_root) else str(path) for path in receipts]
    (output_dir / "receipt-index.json").write_text(json.dumps({"package_hash": runtime_contract_hash(plugin_root), "receipts": relative}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "phase": "agent-usability-trials", "receipts": relative}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
