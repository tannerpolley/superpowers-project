"""Production workflow runtime over immutable authorization and replayed events."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Mapping

try:
    from .workflow_policy import GovernanceProfile, resolve_gate, validate_governance
    from .workflow_state import WorkflowStateError, append_event, replay_events
except ImportError:
    from workflow_policy import GovernanceProfile, resolve_gate, validate_governance
    from workflow_state import WorkflowStateError, append_event, replay_events


class WorkflowRuntimeError(ValueError):
    """Authorization, scope, or transition evidence failed validation."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _hash(value: Mapping[str, Any]) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


class WorkflowRuntime:
    def __init__(self, plugin_root: Path, project_root: Path, run_root: Path, authorization_path: Path):
        self.plugin_root = plugin_root.resolve()
        self.project_root = project_root.resolve()
        self.run_root = run_root.resolve()
        self.authorization_path = authorization_path.resolve()
        self._require_under(self.project_root, self.run_root, "run root")
        self._require_under(self.project_root, self.authorization_path, "authorization")

    @staticmethod
    def _require_under(root: Path, path: Path, label: str) -> None:
        try:
            path.relative_to(root)
        except ValueError as exc:
            raise WorkflowRuntimeError(f"{label} is outside project root") from exc

    def _authorization(self) -> dict[str, Any]:
        if not self.authorization_path.is_file():
            raise WorkflowRuntimeError("authorization ledger is missing")
        value = json.loads(self.authorization_path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise WorkflowRuntimeError("authorization ledger must be a JSON object")
        expected_root = value.get("repo_root")
        if expected_root and Path(str(expected_root)).resolve() != self.project_root:
            raise WorkflowRuntimeError("authorization repo_root does not match active project root")
        return value

    @property
    def context_path(self) -> Path:
        return self.run_root / "context.json"

    def _context(self) -> dict[str, Any]:
        if not self.context_path.is_file():
            raise WorkflowRuntimeError("workflow run has not started")
        value = json.loads(self.context_path.read_text(encoding="utf-8"))
        authorization = self._authorization()
        if value.get("project_root") != str(self.project_root):
            raise WorkflowRuntimeError("workflow project scope changed")
        if value.get("authorization_hash") != _hash(authorization):
            raise WorkflowRuntimeError("workflow authorization changed after start")
        replay_events(self.run_root / "events.jsonl")
        return value

    def _profile(self, authorization: Mapping[str, Any], mode: str) -> GovernanceProfile:
        return validate_governance(
            mode,
            authorization,
            noninteractive_trial=authorization.get("source") == "trial-fixture",
        )

    def start(self, run_id: str, mode: str | None = None) -> dict[str, Any]:
        if self.context_path.exists() or (self.run_root / "events.jsonl").exists():
            raise WorkflowRuntimeError("workflow run already started")
        authorization = self._authorization()
        selected_mode = str(mode or authorization.get("mode") or authorization.get("selected_mode") or "")
        if selected_mode == "loop":
            selected_mode = "looping"
        self._profile(authorization, selected_mode)
        if not run_id.strip():
            raise WorkflowRuntimeError("RunId is required")
        self.run_root.mkdir(parents=True, exist_ok=False)
        context = {
            "run_id": run_id,
            "mode": selected_mode,
            "project_root": str(self.project_root),
            "plugin_root": str(self.plugin_root),
            "authorization_path": str(self.authorization_path),
            "authorization_hash": _hash(authorization),
        }
        self.context_path.write_text(json.dumps(context, sort_keys=True, indent=2) + "\n", encoding="utf-8")
        append_event(self.run_root, {"type": "run_started", "run_id": run_id, "mode": selected_mode, "project_root": str(self.project_root), "authorization_hash": context["authorization_hash"]})
        return self.receipt("start")

    def _candidate(self, candidate: str) -> tuple[dict[str, Any], Any]:
        context = self._context()
        projection = replay_events(self.run_root / "events.jsonl")
        if projection.status != "running":
            raise WorkflowRuntimeError(f"workflow run is {projection.status}")
        if not candidate.strip():
            raise WorkflowRuntimeError("Candidate is required")
        return context, projection

    def select(self, candidate: str) -> dict[str, Any]:
        context, projection = self._candidate(candidate)
        authorization = self._authorization()
        scope = authorization.get("candidate_scope") or []
        if scope and candidate not in scope:
            raise WorkflowRuntimeError("candidate is outside the authorized scope")
        if context["mode"] == "auto" and projection.selected_candidate is not None:
            raise WorkflowRuntimeError("Auto mode authorizes exactly one selected route")
        append_event(self.run_root, {"type": "candidate_selected", "candidate": candidate})
        return self.receipt("select")

    def record(self, action: str, candidate: str) -> dict[str, Any]:
        context, projection = self._candidate(candidate)
        if projection.selected_candidate != candidate:
            raise WorkflowRuntimeError("event candidate must be the active selected candidate")
        event_types = {
            "mutate": "mutation_applied",
            "accept": "candidate_accepted",
            "verify": "verifier_passed",
            "recheck-budget": "budget_rechecked",
            "grant-continuation": "continuation_granted",
        }
        event_type = event_types.get(action)
        if event_type is None:
            raise WorkflowRuntimeError(f"unknown workflow action: {action}")
        event = {"type": event_type, "candidate": candidate}
        if action == "grant-continuation":
            if context["mode"] != "looping":
                raise WorkflowRuntimeError("continuation is only valid in Looping mode")
            if not all(
                candidate in values
                for values in (
                    projection.accepted_candidates,
                    projection.verified_candidates,
                    projection.budget_rechecks,
                )
            ):
                raise WorkflowRuntimeError("continuation requires acceptance, verifier, and budget evidence")
            event["source"] = "policy"
        append_event(self.run_root, event)
        return self.receipt(action)

    def block(self, reason: str) -> dict[str, Any]:
        self._context()
        if not reason.strip():
            raise WorkflowRuntimeError("Reason is required")
        append_event(self.run_root, {"type": "run_stopped", "reason": reason})
        return self.receipt("block")

    def resolve(
        self,
        gate_id: str,
        options: list[str],
        recommendation: str,
        *,
        selected_option: str | None = None,
        authorized: bool = True,
    ) -> dict[str, Any]:
        context = self._context()
        authorization = self._authorization()
        decision = resolve_gate(
            self._profile(authorization, context["mode"]),
            gate_id,
            options,
            recommendation,
            authorized=authorized,
            selected=selected_option,
        )
        if decision.action == "decide":
            append_event(
                self.run_root,
                {
                    "type": "gate_resolved",
                    "gate_id": gate_id,
                    "selected_option": decision.selected_option,
                    "source": decision.source,
                },
            )
        elif decision.action == "block":
            append_event(self.run_root, {"type": "run_stopped", "reason": decision.reason})
        return self.receipt("resolve-gate", decision=decision.as_dict())

    def complete(self, claim: str) -> dict[str, Any]:
        try:
            from .workflow_completion import load_profiles, validate_completion_claim
        except ImportError:
            from workflow_completion import load_profiles, validate_completion_claim

        context = self._context()
        projection = replay_events(self.run_root / "events.jsonl")
        profiles = load_profiles(self.plugin_root / "docs" / "superpowers" / "governance-profiles.yml")
        profile = profiles.get(context["mode"])
        if profile is None:
            raise WorkflowRuntimeError(f"governance profile is missing: {context['mode']}")
        validate_completion_claim(profile, claim, projection, self._authorization())
        candidate = projection.selected_candidate
        append_event(self.run_root, {"type": "run_completed", "claim": claim, "candidate": candidate})
        return self.receipt("complete", completion_claim=claim)

    def receipt(self, action: str, **extra: Any) -> dict[str, Any]:
        projection = replay_events(self.run_root / "events.jsonl")
        payload = {"ok": True, "phase": "workflow-run", "action": action, "projection": projection.as_dict()}
        payload.update(extra)
        return payload


def execute_workflow_action(
    plugin_root: Path,
    project_root: Path,
    run_root: Path,
    authorization_path: Path,
    action: str,
    *,
    run_id: str = "",
    mode: str = "",
    candidate: str = "",
    claim: str = "",
    reason: str = "",
    gate_id: str = "",
    options: list[str] | None = None,
    recommendation: str = "",
    selected_option: str | None = None,
    authorized: bool = True,
) -> dict[str, Any]:
    runtime = WorkflowRuntime(plugin_root, project_root, run_root, authorization_path)
    if action == "start":
        return runtime.start(run_id, mode or None)
    if action == "select":
        return runtime.select(candidate)
    if action in {"mutate", "accept", "verify", "recheck-budget", "grant-continuation"}:
        return runtime.record(action, candidate)
    if action == "block":
        return runtime.block(reason)
    if action == "resolve-gate":
        return runtime.resolve(
            gate_id,
            options or [],
            recommendation,
            selected_option=selected_option,
            authorized=authorized,
        )
    if action == "complete":
        return runtime.complete(claim)
    raise WorkflowRuntimeError(f"unknown workflow action: {action}")
