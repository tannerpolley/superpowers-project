"""Typed governance profiles shared by Manual, Auto, Loop, and trial runs."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Any

import yaml


class PolicyError(ValueError):
    pass


@dataclass(frozen=True)
class GovernanceProfile:
    name: str
    interactive: bool
    max_candidates_per_iteration: int
    requires_continuation: bool
    completion_claims: tuple[str, ...] = ()


@dataclass(frozen=True)
class GateDecision:
    gate_id: str
    action: str
    selected_option: str | None
    source: str
    reason: str

    def as_dict(self) -> dict[str, str | None]:
        return {
            "gate_id": self.gate_id,
            "action": self.action,
            "selected_option": self.selected_option,
            "source": self.source,
            "reason": self.reason,
        }


def load_governance_profiles(path: Path | None = None) -> dict[str, GovernanceProfile]:
    source = path or Path(__file__).resolve().parents[2] / "docs" / "superpowers" / "governance-profiles.yml"
    data = yaml.safe_load(source.read_text(encoding="utf-8")) or {}
    profiles: dict[str, GovernanceProfile] = {}
    for name, value in (data.get("profiles") or {}).items():
        profiles[name] = GovernanceProfile(
            name=name,
            interactive=value.get("interactive") is True,
            max_candidates_per_iteration=int(value.get("max_candidates_per_iteration", 0)),
            requires_continuation=value.get("requires_continuation") is True,
            completion_claims=tuple(value.get("completion_claims") or ()),
        )
    if not profiles:
        raise PolicyError("governance profiles are missing")
    return profiles


def validate_governance(mode: str, authorization: Mapping[str, Any], *, noninteractive_trial: bool = False) -> GovernanceProfile:
    profile = load_governance_profiles().get(mode)
    if profile is None:
        raise PolicyError(f"unknown governance profile: {mode}")
    source = authorization.get("source")
    if profile.interactive and source != "request_user_input":
        raise PolicyError("manual governance requires request_user_input")
    if noninteractive_trial and source != "trial-fixture":
        raise PolicyError("noninteractive trial requires trial-fixture provenance")
    candidates = authorization.get("candidate_scope") or []
    if not isinstance(candidates, list) or not candidates or (mode != "looping" and len(candidates) > profile.max_candidates_per_iteration):
        raise PolicyError("candidate scope exceeds one-candidate iteration bound")
    if mode == "looping" and len(authorization.get("selected_candidates") or []) > profile.max_candidates_per_iteration:
        raise PolicyError("loop iteration selected more than one candidate")
    if mode == "auto" and authorization.get("continuation_grant"):
        raise PolicyError("Auto mode cannot carry a continuation grant")
    return profile


def validate_loop_evidence(candidate: str, budget: Mapping[str, Any], health: Mapping[str, Any]) -> None:
    """Validate the existing Loop budget and verifier ledgers for one candidate."""
    if budget.get("candidate_id") != candidate or health.get("candidate_id") != candidate:
        raise PolicyError("Loop evidence must match the active candidate")
    limits = (
        ("candidates_completed", "max_candidates", True),
        ("current_phase_attempts", "max_attempts_per_phase", True),
        ("repeated_same_failure_count", "max_repeated_same_failure", True),
        ("changed_files", "max_changed_files", False),
        ("github_mutations", "max_github_mutations", False),
        ("validator_reruns", "max_validator_reruns", False),
        ("unreviewed_diff_lines", "max_unreviewed_diff_lines", False),
    )
    for actual, maximum, exclusive in limits:
        if actual not in budget or maximum not in budget:
            raise PolicyError(f"Loop budget evidence is missing {actual} or {maximum}")
        exhausted = int(budget[actual]) >= int(budget[maximum]) if exclusive else int(budget[actual]) > int(budget[maximum])
        if exhausted:
            raise PolicyError(f"Loop budget exhausted: {actual}")
    proof = health.get("proof")
    if health.get("independent") is not True or not isinstance(proof, list) or not proof:
        raise PolicyError("Loop health requires independent verifier proof")
    if any(not isinstance(item, Mapping) or item.get("ok") is not True for item in proof):
        raise PolicyError("Loop health proof failed")


def resolve_gate(
    profile: GovernanceProfile,
    gate_id: str,
    options: list[str],
    recommendation: str,
    *,
    authorized: bool = True,
    selected: str | None = None,
) -> GateDecision:
    """Apply the shared Manual/Auto/Loop gate rule without inventing authority."""
    if not gate_id.strip():
        raise PolicyError("gate_id is required")
    if not options or any(not str(option).strip() for option in options) or len(set(options)) != len(options):
        raise PolicyError("gate options must be non-empty and unique")
    if profile.interactive:
        if selected is None:
            return GateDecision(gate_id, "ask", None, "user", "manual mode requires native input")
        if selected not in options:
            raise PolicyError("selected option is not available")
        return GateDecision(gate_id, "decide", selected, "user", "recorded user selection")
    if selected is not None:
        raise PolicyError("noninteractive gates do not accept caller-selected answers")
    if not authorized or recommendation not in options:
        return GateDecision(gate_id, "block", None, "policy", "no authorized recommended option")
    return GateDecision(gate_id, "decide", recommendation, "policy", "selected safe recommendation")
