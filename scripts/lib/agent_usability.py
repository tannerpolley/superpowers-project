"""Independent validation for fresh-agent workflow trial receipts."""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any
import uuid

try:
    from .package_provenance import runtime_contract_hash
    from .workflow_state import replay_events
except ImportError:
    from package_provenance import runtime_contract_hash
    from workflow_state import replay_events


class TrialReceiptError(ValueError):
    pass


REQUIRED = {
    "schema_version", "trial_id", "scenario", "repetition", "worker", "verifier",
    "package_hash", "trial_root", "project_root", "expected_outcome", "observed_outcome",
    "friction", "user_input_calls", "external_mutations", "repository_evidence",
    "event_ledger", "worker_claim", "verifier_decision",
}


def validate_trial_receipt(receipt: dict[str, Any], plugin_root: Path) -> None:
    missing = sorted(REQUIRED - set(receipt))
    if missing:
        raise TrialReceiptError("missing receipt fields: " + ", ".join(missing))
    if receipt.get("schema_version") != 1:
        raise TrialReceiptError("schema_version must be 1")
    scenario = receipt.get("scenario")
    expected_by_scenario = {"auto-golden": "pass", "loop-adversarial": "blocked"}
    if scenario not in expected_by_scenario:
        raise TrialReceiptError("unknown trial scenario")
    if receipt.get("expected_outcome") != expected_by_scenario[scenario]:
        raise TrialReceiptError("expected outcome does not match the scenario oracle")
    if receipt.get("expected_outcome") != receipt.get("observed_outcome"):
        raise TrialReceiptError("observed outcome does not match untouched oracle")
    agent_ids = []
    for role in ("worker", "verifier"):
        agent_id = str((receipt.get(role) or {}).get("id", ""))
        try:
            uuid.UUID(agent_id)
        except (ValueError, AttributeError) as exc:
            raise TrialReceiptError(f"{role} id must be an actual Codex session id") from exc
        agent_ids.append(agent_id)
    if agent_ids[0] == agent_ids[1]:
        raise TrialReceiptError("worker and verifier must be independent agents")
    if receipt.get("package_hash") != runtime_contract_hash(plugin_root):
        raise TrialReceiptError("trial receipt package hash is stale")
    trial_root = Path(str(receipt.get("trial_root")))
    project_root = Path(str(receipt.get("project_root")))
    if not trial_root.is_absolute():
        trial_root = plugin_root / trial_root
    if not project_root.is_absolute():
        project_root = plugin_root / project_root
    trial_root = trial_root.resolve()
    project_root = project_root.resolve()
    try:
        project_root.relative_to(trial_root)
    except ValueError as exc:
        raise TrialReceiptError("trial project escaped its disposable root") from exc
    friction = receipt.get("friction")
    if not isinstance(friction, int) or not 1 <= friction <= 5:
        raise TrialReceiptError("friction must be an integer from 1 through 5")
    if receipt.get("user_input_calls") != 0:
        raise TrialReceiptError("autonomous trial used native user input")
    if receipt.get("external_mutations") != 0:
        raise TrialReceiptError("trial attempted external mutation")
    if not isinstance(receipt.get("repository_evidence"), list) or not receipt["repository_evidence"]:
        raise TrialReceiptError("repository evidence is required")
    for item in receipt["repository_evidence"]:
        evidence_path = Path(str((item or {}).get("path", "")))
        if evidence_path.is_absolute():
            raise TrialReceiptError("repository evidence paths must be relative")
        evidence_path = (project_root / evidence_path).resolve()
        try:
            evidence_path.relative_to(project_root)
        except ValueError as exc:
            raise TrialReceiptError("repository evidence escaped the disposable project") from exc
        if not evidence_path.is_file():
            raise TrialReceiptError("repository evidence file is missing")
        expected_digest = str((item or {}).get("sha256", ""))
        if hashlib.sha256(evidence_path.read_bytes()).hexdigest() != expected_digest:
            raise TrialReceiptError("repository evidence hash does not match receipt")
    ledger = receipt.get("event_ledger") or {}
    ledger_path = Path(str(ledger.get("path", "")))
    if not ledger_path.is_absolute():
        ledger_path = project_root / ledger_path
    if not ledger_path.is_file():
        raise TrialReceiptError("event ledger is missing")
    projection = replay_events(ledger_path)
    if projection.events == 0:
        raise TrialReceiptError("event ledger is empty")
    if projection.last_hash != ledger.get("last_hash"):
        raise TrialReceiptError("event ledger hash does not match receipt")
    if scenario == "auto-golden":
        candidate = projection.selected_candidate
        merge_done = any(
            decision.get("gate_id") == "project_merge_final_health_gate"
            and decision.get("selected_option") == "Done"
            for decision in projection.gate_decisions
        )
        if (
            projection.status != "completed"
            or not candidate
            or candidate not in projection.accepted_candidates
            or candidate not in projection.verified_candidates
            or projection.mutation_count < 1
            or not merge_done
        ):
            raise TrialReceiptError("Auto trial did not reach verified outcome closeout")
    elif (
        projection.status != "running"
        or projection.selected_candidates != ["one"]
        or projection.mutation_count != 1
    ):
        raise TrialReceiptError("Loop adversarial trial did not block before a second candidate mutation")
    if receipt.get("verifier_decision") != receipt.get("expected_outcome"):
        raise TrialReceiptError("independent verifier did not confirm the expected outcome")


def validate_trial_set(receipts: list[dict[str, Any]], plugin_root: Path) -> dict[str, Any]:
    for receipt in receipts:
        validate_trial_receipt(receipt, plugin_root)
    auto = [item for item in receipts if item["scenario"] == "auto-golden"]
    loop = [item for item in receipts if item["scenario"] == "loop-adversarial"]
    if len(auto) < 5 or len(loop) < 3:
        raise TrialReceiptError("trial set requires five Auto and three Looping repetitions")
    friction = sorted(item["friction"] for item in receipts)
    median = (friction[(len(friction) - 1) // 2] + friction[len(friction) // 2]) / 2
    if median > 2:
        raise TrialReceiptError("median trial friction exceeds 2")
    return {"auto_repetitions": len(auto), "loop_repetitions": len(loop), "median_friction": median, "user_input_calls": 0, "external_mutations": 0}
