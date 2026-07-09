#!/usr/bin/env python3
"""Run fresh Codex workers and independent verifiers in durable disposable fixtures."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from package_provenance import runtime_contract_hash


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def invoke_agent(project: Path, prompt: str, schema: Path, output: Path) -> dict:
    result = run([
        "codex", "exec", "--ephemeral", "--ignore-user-config", "--sandbox", "workspace-write",
        "--skip-git-repo-check", "-C", str(project), "--output-schema", str(schema),
        "--output-last-message", str(output), prompt,
    ], project)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Codex worker failed")
    return json.loads(output.read_text(encoding="utf-8"))


def runtime_call(plugin_root: Path, project: Path, run_root: Path, authorization: Path, action: str, *extra: str) -> None:
    result = run(["bash", str(plugin_root / "scripts" / "workflow-run.sh"), "-RepoRoot", str(project), "-RunRoot", str(run_root), "-AuthorizationPath", str(authorization), "-Action", action, *extra], project)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())


def create_fixture(plugin_root: Path, trial_root: Path, scenario: str, repetition: int) -> tuple[Path, Path, Path]:
    project = trial_root / "project"
    project.mkdir(parents=True)
    run(["git", "init", "-q"], project)
    authorization = project / "authorization.json"
    mode = "auto" if scenario == "auto-golden" else "looping"
    authorization.write_text(json.dumps({"source": "trial-fixture", "mode": mode, "repo_root": str(project.resolve()), "candidate_scope": ["one"] if mode == "auto" else ["one", "two"]}, indent=2) + "\n")
    (project / "result.txt").write_text("pending\n")
    run_root = project / ".superpowers" / "runs" / f"{scenario}-{repetition}"
    if scenario == "loop-adversarial":
        runtime_call(plugin_root, project, run_root, authorization, "start", "-RunId", f"{scenario}-{repetition}")
        runtime_call(plugin_root, project, run_root, authorization, "select", "-Candidate", "one")
        runtime_call(plugin_root, project, run_root, authorization, "mutate", "-Candidate", "one")
    return project, run_root, authorization


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--scenario", choices=["auto-golden", "loop-adversarial", "all"], default="all")
    parser.add_argument("--auto-repetitions", type=int, default=5)
    parser.add_argument("--loop-repetitions", type=int, default=3)
    args = parser.parse_args()
    if not args.execute:
        parser.error("--execute is required because this command starts fresh Codex agents")
    if shutil.which("codex") is None:
        parser.error("codex CLI is required")
    plugin_root = Path(__file__).resolve().parents[1]
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    scenarios = []
    if args.scenario in {"auto-golden", "all"}:
        scenarios.extend([("auto-golden", index) for index in range(1, args.auto_repetitions + 1)])
    if args.scenario in {"loop-adversarial", "all"}:
        scenarios.extend([("loop-adversarial", index) for index in range(1, args.loop_repetitions + 1)])
    worker_schema = plugin_root / "tests" / "workflow-trials" / "worker-output.schema.json"
    verifier_schema = plugin_root / "tests" / "workflow-trials" / "verifier-output.schema.json"
    receipts = []
    for scenario, repetition in scenarios:
        trial_root = output_dir / "runs" / f"{scenario}-{repetition}"
        if trial_root.exists():
            shutil.rmtree(trial_root)
        project, run_root, authorization = create_fixture(plugin_root, trial_root, scenario, repetition)
        prompt_path = plugin_root / "tests" / "workflow-trials" / "scenarios" / ("auto" if scenario == "auto-golden" else "loop") / "prompt.md"
        source_skills = [plugin_root / "skills" / "initiate-workflow" / "SKILL.md", plugin_root / "skills" / ("implement-plan" if scenario == "auto-golden" else "loop-controller") / "SKILL.md"]
        prompt = prompt_path.read_text() + "\n\nRead these exact source contracts first:\n" + "\n".join(f"- {path}" for path in source_skills) + f"\nRuntime: {plugin_root / 'scripts/workflow-run.sh'}\nAuthorization: {authorization}\nRun root: {run_root}\nReturn only the requested JSON."
        worker_id = f"codex-worker-{uuid.uuid4()}"
        worker = invoke_agent(project, prompt, worker_schema, trial_root / "worker-output.json")
        oracle_path = plugin_root / "tests" / "workflow-trials" / "oracles" / ("auto.json" if scenario == "auto-golden" else "loop.json")
        verifier_prompt = f"Act as an independent verifier. Read the untouched oracle {oracle_path}, repository {project}, and event ledger {run_root / 'events.jsonl'}. Do not trust worker narrative. Decide pass or blocked only when repository and replayable event evidence match the oracle. Return only JSON."
        verifier_id = f"codex-verifier-{uuid.uuid4()}"
        verifier = invoke_agent(project, verifier_prompt, verifier_schema, trial_root / "verifier-output.json")
        ledger_path = run_root / "events.jsonl"
        last = json.loads(ledger_path.read_text().splitlines()[-1])
        result_file = project / "result.txt"
        expected = "pass" if scenario == "auto-golden" else "blocked"
        receipt = {
            "schema_version": 1, "trial_id": f"{scenario}-{repetition}", "scenario": scenario, "repetition": repetition,
            "worker": {"id": worker_id}, "verifier": {"id": verifier_id}, "package_hash": runtime_contract_hash(plugin_root),
            "trial_root": str(trial_root), "project_root": str(project), "expected_outcome": expected,
            "observed_outcome": worker["observed_outcome"], "friction": worker["friction"], "user_input_calls": 0,
            "external_mutations": 0, "repository_evidence": [{"path": "result.txt", "sha256": hashlib.sha256(result_file.read_bytes()).hexdigest()}],
            "event_ledger": {"path": str(ledger_path), "last_hash": last["hash"]}, "worker_claim": worker["claim"],
            "verifier_decision": verifier["decision"], "verifier_reason": verifier["reason"],
        }
        receipt_path = trial_root / "receipt.json"
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
        receipts.append(str(receipt_path))
    (output_dir / "receipt-index.json").write_text(json.dumps({"package_hash": runtime_contract_hash(plugin_root), "receipts": receipts}, indent=2) + "\n")
    print(json.dumps({"ok": True, "phase": "agent-usability-trials", "receipts": receipts}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
