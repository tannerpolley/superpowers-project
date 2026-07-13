"""Event-derived, governance-scoped workflow completion claims."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Mapping

import yaml

try:
    from .workflow_policy import GovernanceProfile
    from .workflow_state import RunProjection
except ImportError:
    from workflow_policy import GovernanceProfile
    from workflow_state import RunProjection


class CompletionError(ValueError):
    pass


def load_profiles(path: Path) -> dict[str, GovernanceProfile]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    values = data.get("profiles")
    if not isinstance(values, dict) or not values:
        raise CompletionError("governance profiles must be a non-empty mapping")
    profiles: dict[str, GovernanceProfile] = {}
    for name, value in values.items():
        if not isinstance(value, dict):
            raise CompletionError(f"profile {name} must be a mapping")
        claims = value.get("completion_claims")
        if not isinstance(claims, list) or not claims or any(claim not in {"candidate", "route", "outcome", "iteration", "project"} for claim in claims):
            raise CompletionError(f"profile {name} has invalid completion claims")
        profiles[name] = GovernanceProfile(
            name=name,
            interactive=value.get("interactive") is True,
            max_candidates_per_iteration=int(value.get("max_candidates_per_iteration", 0)),
            requires_continuation=value.get("requires_continuation") is True,
            completion_claims=tuple(claims),
        )
    return profiles


def allowed_completion_claims(profile: GovernanceProfile) -> set[str]:
    return set(profile.completion_claims)


def validate_completion_claim(
    profile: GovernanceProfile,
    claim: str,
    projection: RunProjection,
    authorization: Mapping[str, Any],
) -> None:
    if claim not in allowed_completion_claims(profile):
        raise CompletionError(f"{claim} completion is outside {profile.name} governance")
    candidate = projection.selected_candidate
    if not candidate:
        raise CompletionError("completion requires a selected candidate")
    if candidate not in projection.accepted_candidates:
        raise CompletionError("completion requires candidate acceptance")
    if candidate not in projection.verified_candidates:
        raise CompletionError("completion requires verifier proof")
    if claim in {"route", "outcome"}:
        scope = authorization.get("candidate_scope") or []
        if profile.name == "auto" and (len(scope) != 1 or scope[0] != candidate):
            raise CompletionError("Auto outcome completion must match its one authorized candidate")
    elif claim == "iteration":
        if candidate not in projection.budget_rechecks:
            raise CompletionError("iteration completion requires budget recheck evidence")
        if profile.requires_continuation and candidate not in projection.continuation_grants:
            raise CompletionError("iteration completion requires continuation evidence")
    elif claim == "project" and projection.project_health_verified is not True:
        raise CompletionError("project completion requires project health proof")
