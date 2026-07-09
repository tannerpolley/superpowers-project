"""Append-only workflow run ledger and deterministic state projection.

The ledger is deliberately small and boring: each JSONL record carries the hash
of the previous record and its own canonical-content hash.  Replay is the only
way to derive ``run.json``; callers must not edit the projection directly.
"""
from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping


class WorkflowStateError(ValueError):
    """A malformed ledger or a transition outside the workflow policy."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _digest(value: Mapping[str, Any]) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


@dataclass
class RunProjection:
    run_id: str | None = None
    status: str = "created"
    selected_candidate: str | None = None
    accepted_candidates: list[str] = field(default_factory=list)
    verified_candidates: list[str] = field(default_factory=list)
    budget_rechecks: list[str] = field(default_factory=list)
    continuation_grants: list[str] = field(default_factory=list)
    mutation_count: int = 0
    project_health_verified: bool = False
    events: int = 0
    last_hash: str = "0" * 64

    def as_dict(self) -> dict[str, Any]:
        return {
            "run_id": self.run_id,
            "status": self.status,
            "selected_candidate": self.selected_candidate,
            "accepted_candidates": list(self.accepted_candidates),
            "verified_candidates": list(self.verified_candidates),
            "budget_rechecks": list(self.budget_rechecks),
            "continuation_grants": list(self.continuation_grants),
            "mutation_count": self.mutation_count,
            "project_health_verified": self.project_health_verified,
            "events": self.events,
            "last_hash": self.last_hash,
        }


def _transition(projection: RunProjection, event: Mapping[str, Any]) -> None:
    kind = event.get("type")
    candidate = event.get("candidate")
    if kind == "run_started":
        if projection.events:
            raise WorkflowStateError("run_started must be the first event")
        projection.run_id = str(event.get("run_id") or "") or None
        projection.status = "running"
    elif kind == "candidate_selected":
        if not candidate:
            raise WorkflowStateError("candidate_selected requires candidate")
        if projection.selected_candidate is not None:
            previous = projection.selected_candidate
            ready = (
                previous in projection.accepted_candidates
                and previous in projection.verified_candidates
                and previous in projection.budget_rechecks
                and previous in projection.continuation_grants
            )
            if not ready:
                raise WorkflowStateError("second candidate requires acceptance, verifier, budget recheck, and continuation grant")
        projection.selected_candidate = str(candidate)
    elif kind in {"candidate_accepted", "verifier_passed", "budget_rechecked", "continuation_granted"}:
        if not candidate:
            raise WorkflowStateError(f"{kind} requires candidate")
        target = {
            "candidate_accepted": projection.accepted_candidates,
            "verifier_passed": projection.verified_candidates,
            "budget_rechecked": projection.budget_rechecks,
            "continuation_granted": projection.continuation_grants,
        }[kind]
        if str(candidate) not in target:
            target.append(str(candidate))
    elif kind == "mutation_applied":
        if projection.selected_candidate is None:
            raise WorkflowStateError("mutation requires a selected candidate")
        projection.mutation_count += 1
    elif kind == "project_health_verified":
        projection.project_health_verified = True
    elif kind == "run_stopped":
        projection.status = "stopped"
    elif kind == "run_completed":
        projection.status = "completed"
    else:
        raise WorkflowStateError(f"unsupported event type: {kind}")


def append_event(run_root: str | os.PathLike[str], event: Mapping[str, Any]) -> dict[str, Any]:
    """Append one validated event and rewrite the deterministic projection."""
    root = Path(run_root)
    root.mkdir(parents=True, exist_ok=True)
    events_path = root / "events.jsonl"
    projection = replay_events(events_path) if events_path.exists() else RunProjection()
    record = dict(event)
    if not record.get("type"):
        raise WorkflowStateError("event type is required")
    record.setdefault("run_id", projection.run_id)
    record["seq"] = projection.events
    record["prev_hash"] = projection.last_hash
    record["hash"] = _digest({k: v for k, v in record.items() if k != "hash"})
    _transition(projection, record)
    with events_path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n")
    projection.events += 1
    projection.last_hash = record["hash"]
    (root / "run.json").write_text(json.dumps(projection.as_dict(), sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return record


def replay_events(events_path: str | os.PathLike[str]) -> RunProjection:
    """Verify and deterministically replay a JSONL event ledger."""
    path = Path(events_path)
    projection = RunProjection()
    if not path.exists():
        return projection
    with path.open(encoding="utf-8") as stream:
        for expected_seq, line in enumerate(stream):
            if not line.strip():
                raise WorkflowStateError("blank event line")
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                raise WorkflowStateError(f"invalid event JSON at sequence {expected_seq}") from exc
            if record.get("seq") != expected_seq:
                raise WorkflowStateError("event sequence is not contiguous")
            if record.get("prev_hash") != projection.last_hash:
                raise WorkflowStateError("event hash chain is broken")
            supplied = record.get("hash")
            if supplied != _digest({k: v for k, v in record.items() if k != "hash"}):
                raise WorkflowStateError("event hash does not match canonical content")
            _transition(projection, record)
            projection.events += 1
            projection.last_hash = supplied
    return projection


def write_projection(run_root: str | os.PathLike[str]) -> RunProjection:
    """Replay the ledger and refresh ``run.json`` without trusting its contents."""
    root = Path(run_root)
    projection = replay_events(root / "events.jsonl")
    (root / "run.json").write_text(
        json.dumps(projection.as_dict(), sort_keys=True, indent=2) + "\n", encoding="utf-8"
    )
    return projection


def require_second_candidate_ready(projection: RunProjection, candidate: str) -> None:
    """Explicit gate used by Loop mode before selecting another candidate."""
    if projection.selected_candidate is None:
        raise WorkflowStateError("cannot select second candidate before first candidate")
    first = projection.selected_candidate
    if not all(
        first in values
        for values in (
            projection.accepted_candidates,
            projection.verified_candidates,
            projection.budget_rechecks,
            projection.continuation_grants,
        )
    ):
        raise WorkflowStateError("second candidate requires acceptance, verifier, budget recheck, and continuation grant")
    if candidate == first:
        raise WorkflowStateError("candidate is already selected")
