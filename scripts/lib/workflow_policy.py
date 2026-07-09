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
    if not profile.interactive and source == "request_user_input" and not noninteractive_trial:
        raise PolicyError("noninteractive governance cannot silently depend on request_user_input")
    if noninteractive_trial and source != "trial-fixture":
        raise PolicyError("noninteractive trial requires trial-fixture provenance")
    candidates = authorization.get("candidate_scope") or []
    if not isinstance(candidates, list) or (mode != "looping" and len(candidates) > profile.max_candidates_per_iteration):
        raise PolicyError("candidate scope exceeds one-candidate iteration bound")
    if mode == "looping" and len(authorization.get("selected_candidates") or []) > profile.max_candidates_per_iteration:
        raise PolicyError("loop iteration selected more than one candidate")
    if mode == "auto" and authorization.get("continuation_grant"):
        raise PolicyError("Auto mode cannot carry a continuation grant")
    return profile
