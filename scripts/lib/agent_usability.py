"""Independent validation for fresh-agent Project Truss trial receipts."""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any
import uuid

try:
    from .package_provenance import runtime_contract_hash
except ImportError:
    from package_provenance import runtime_contract_hash


class TrialReceiptError(ValueError):
    pass


REQUIRED = {
    "schema_version", "trial_id", "scenario", "repetition", "worker", "verifier", "package_hash",
    "oracle_sha256", "trial_root", "project_root", "expected_outcome", "observed_outcome", "friction",
    "user_input_calls", "external_mutations", "repository_evidence", "worker_claim", "verifier_decision",
}


def _within(value: str, base: Path, plugin_root: Path) -> Path:
    path = Path(value)
    path = plugin_root / path if not path.is_absolute() else path
    resolved = path.resolve()
    try:
        resolved.relative_to(base.resolve())
    except ValueError as exc:
        raise TrialReceiptError("trial path escaped its declared root") from exc
    return resolved


def validate_trial_receipt(receipt: dict[str, Any], plugin_root: Path) -> None:
    missing = sorted(REQUIRED - set(receipt))
    if missing:
        raise TrialReceiptError("missing receipt fields: " + ", ".join(missing))
    if receipt.get("schema_version") != 1 or not isinstance(receipt.get("scenario"), str) or not receipt["scenario"]:
        raise TrialReceiptError("invalid trial schema or scenario")
    if receipt.get("expected_outcome") not in {"pass", "blocked"} or receipt.get("observed_outcome") != receipt.get("expected_outcome"):
        raise TrialReceiptError("observed outcome does not match the scenario oracle")
    if not isinstance(receipt.get("oracle_sha256"), str) or len(receipt["oracle_sha256"]) != 64:
        raise TrialReceiptError("oracle hash must be a SHA-256 digest")
    agent_ids = []
    for role in ("worker", "verifier"):
        value = str((receipt.get(role) or {}).get("id", ""))
        try:
            uuid.UUID(value)
        except (ValueError, AttributeError) as exc:
            raise TrialReceiptError(f"{role} id must be an actual Codex session id") from exc
        agent_ids.append(value)
    if agent_ids[0] == agent_ids[1]:
        raise TrialReceiptError("worker and verifier must be independent agents")
    if receipt.get("package_hash") != runtime_contract_hash(plugin_root):
        raise TrialReceiptError("trial receipt package hash is stale")
    trial_value = Path(str(receipt.get("trial_root")))
    trial_root = (plugin_root / trial_value).resolve() if not trial_value.is_absolute() else trial_value.resolve()
    project_root = _within(str(receipt.get("project_root")), trial_root, plugin_root)
    if not isinstance(receipt.get("friction"), int) or not 1 <= receipt["friction"] <= 5:
        raise TrialReceiptError("friction must be an integer from 1 through 5")
    if receipt.get("user_input_calls") != 0 or receipt.get("external_mutations") != 0:
        raise TrialReceiptError("trial crossed a forbidden boundary")
    evidence = receipt.get("repository_evidence")
    if not isinstance(evidence, list) or not evidence:
        raise TrialReceiptError("repository evidence is required")
    for item in evidence:
        relative = Path(str((item or {}).get("path", "")))
        if relative.is_absolute():
            raise TrialReceiptError("repository evidence paths must be relative")
        path = _within(str(project_root / relative), project_root, plugin_root)
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != str((item or {}).get("sha256", "")):
            raise TrialReceiptError("repository evidence is missing or stale")
    if receipt.get("verifier_decision") != receipt.get("expected_outcome"):
        raise TrialReceiptError("independent verifier did not confirm the outcome")


def validate_trial_set(receipts: list[dict[str, Any]], plugin_root: Path) -> dict[str, Any]:
    if not receipts:
        raise TrialReceiptError("trial set is empty")
    for receipt in receipts:
        validate_trial_receipt(receipt, plugin_root)
    friction = sorted(item["friction"] for item in receipts)
    median = (friction[(len(friction) - 1) // 2] + friction[len(friction) // 2]) / 2
    if median > 2:
        raise TrialReceiptError("median trial friction exceeds 2")
    scenarios = sorted({item["scenario"] for item in receipts})
    return {"scenarios": scenarios, "repetitions": len(receipts), "median_friction": median, "user_input_calls": 0, "external_mutations": 0}
