"""Independent validation for fresh-agent workflow trial receipts."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

try:
    from .package_provenance import runtime_contract_hash
except ImportError:
    from package_provenance import runtime_contract_hash


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
    if receipt.get("scenario") not in {"auto-golden", "loop-adversarial"}:
        raise TrialReceiptError("unknown trial scenario")
    if receipt.get("expected_outcome") != receipt.get("observed_outcome"):
        raise TrialReceiptError("observed outcome does not match untouched oracle")
    if (receipt.get("worker") or {}).get("id") == (receipt.get("verifier") or {}).get("id"):
        raise TrialReceiptError("worker and verifier must be independent agents")
    if receipt.get("package_hash") != runtime_contract_hash(plugin_root):
        raise TrialReceiptError("trial receipt package hash is stale")
    trial_root = Path(str(receipt.get("trial_root"))).resolve()
    project_root = Path(str(receipt.get("project_root"))).resolve()
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
    ledger = receipt.get("event_ledger") or {}
    ledger_path = Path(str(ledger.get("path", "")))
    if not ledger_path.is_absolute():
        ledger_path = project_root / ledger_path
    if not ledger_path.is_file():
        raise TrialReceiptError("event ledger is missing")
    lines = [line for line in ledger_path.read_text(encoding="utf-8").splitlines() if line]
    if not lines:
        raise TrialReceiptError("event ledger is empty")
    last = json.loads(lines[-1])
    if last.get("hash") != ledger.get("last_hash"):
        raise TrialReceiptError("event ledger hash does not match receipt")
    if receipt.get("verifier_decision") not in {"pass", "blocked"}:
        raise TrialReceiptError("independent verifier did not accept the expected outcome")


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
