"""Typed governance profiles shared by Manual, Auto, Loop, and trial runs."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Any


class PolicyError(ValueError):
    pass


@dataclass(frozen=True)
class GovernanceProfile:
    name: str
    interactive: bool
    max_candidates_per_iteration: int
    requires_continuation: bool


PROFILES = {
    "manual": GovernanceProfile("manual", True, 1, True),
    "auto": GovernanceProfile("auto", False, 1, False),
    "looping": GovernanceProfile("looping", False, 1, True),
    "trial.local": GovernanceProfile("trial.local", False, 1, True),
}


def validate_governance(mode: str, authorization: Mapping[str, Any], *, noninteractive_trial: bool = False) -> GovernanceProfile:
    profile = PROFILES.get(mode)
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
