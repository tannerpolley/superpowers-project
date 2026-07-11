"""Strict, repository-bound evidence envelopes for execution gates."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path
from typing import Any, Callable, Mapping, NewType


SUPPORTED_GATES = frozenset({"pr_ready", "premerge", "merge_decision", "closeout", "publish_ready"})
HASH_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
TIMESTAMP_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$")
HashRef = NewType("HashRef", str)


class EvidenceError(ValueError):
    def __init__(self, code: str, message: str, rule: str | None = None):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message
        self.rule = rule


def canonical_json(value: object) -> bytes:
    _validate_json_value(value, "$")
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode("utf-8")


def _validate_json_value(value: object, path: str) -> None:
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise EvidenceError("schema_invalid", f"non-finite number at {path}")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _validate_json_value(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise EvidenceError("schema_invalid", f"non-string object key at {path}")
            _validate_json_value(item, f"{path}.{key}")
        return
    raise EvidenceError("schema_invalid", f"unsupported JSON value at {path}")


def hash_ref(value: object) -> HashRef:
    return HashRef("sha256:" + hashlib.sha256(canonical_json(value)).hexdigest())


def hash_bytes_ref(value: bytes) -> HashRef:
    return HashRef("sha256:" + hashlib.sha256(value).hexdigest())


def is_hash_ref(value: object) -> bool:
    return isinstance(value, str) and HASH_PATTERN.fullmatch(value) is not None


def _strict_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError("schema_invalid", f"duplicate_key:{key}")
        result[key] = value
    return result


def _mapping(value: object, label: str) -> Mapping[str, object]:
    if not isinstance(value, Mapping):
        raise EvidenceError("schema_invalid", f"{label} must be an object")
    return value


def _keys(value: Mapping[str, object], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        unknown = sorted(actual - expected)
        missing = sorted(expected - actual)
        detail = []
        if unknown:
            detail.append("unknown=" + ",".join(unknown))
        if missing:
            detail.append("missing=" + ",".join(missing))
        raise EvidenceError("schema_invalid", f"{label} keys invalid ({'; '.join(detail)})")


def _string(value: object, label: str, *, allow_none: bool = False) -> str | None:
    if allow_none and value is None:
        return None
    if not isinstance(value, str) or not value:
        raise EvidenceError("schema_invalid", f"{label} must be a non-empty string")
    return value


def _hash(value: object, label: str, *, allow_none: bool = False) -> str | None:
    if allow_none and value is None:
        return None
    if not is_hash_ref(value):
        raise EvidenceError("schema_invalid", f"{label} must be a HashRef")
    return str(value)


def _canonical_path(value: object, label: str) -> Path:
    path = _string(value, label)
    assert path is not None
    candidate = Path(path)
    if not candidate.is_absolute():
        raise EvidenceError("repository_mismatch", f"{label} must be absolute")
    return candidate.resolve(strict=False)


def _repo_relative_path(value: object, repo_root: Path, label: str, *, allow_none: bool = False) -> str | None:
    if allow_none and value is None:
        return None
    path_value = _string(value, label)
    assert path_value is not None
    candidate = Path(path_value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise EvidenceError("repository_mismatch", f"{label} escapes repository")
    resolved = (repo_root / candidate).resolve(strict=False)
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise EvidenceError("repository_mismatch", f"{label} escapes repository") from exc
    if not resolved.is_file():
        raise EvidenceError("repository_mismatch", f"{label} does not exist")
    return candidate.as_posix()


def _expected_git_common_dir(repo_root: Path) -> Path:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=repo_root,
            stdin=subprocess.DEVNULL,
            text=True,
            capture_output=True,
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        result = None
    if result and result.returncode == 0 and result.stdout.strip():
        value = Path(result.stdout.strip())
        return (repo_root / value if not value.is_absolute() else value).resolve()
    return (repo_root / ".git").resolve()


@dataclass(frozen=True)
class EvidenceKindRegistration:
    kind: str
    version: str
    validator: Callable[[Mapping[str, object]], None] | None = None


@dataclass(frozen=True)
class EvidenceItem:
    kind: str
    collector: str
    observed_at: str
    payload_hash: HashRef
    payload: Mapping[str, object]

    def to_dict(self) -> dict[str, object]:
        return {
            "kind": self.kind,
            "collector": self.collector,
            "observed_at": self.observed_at,
            "payload_hash": self.payload_hash,
            "payload": dict(self.payload),
        }


@dataclass(frozen=True)
class EvidenceEnvelope:
    schema_version: int
    gate: str
    repository: Mapping[str, object]
    workflow: Mapping[str, object]
    source: Mapping[str, object]
    target: Mapping[str, object]
    evidence: tuple[EvidenceItem, ...]
    prior_event_hash: HashRef | None
    envelope_hash: HashRef

    def to_dict(self, *, include_hash: bool = True) -> dict[str, object]:
        result: dict[str, object] = {
            "schema_version": self.schema_version,
            "gate": self.gate,
            "repository": dict(self.repository),
            "workflow": dict(self.workflow),
            "source": dict(self.source),
            "target": dict(self.target),
            "evidence": [item.to_dict() for item in self.evidence],
            "prior_event_hash": self.prior_event_hash,
        }
        if include_hash:
            result["envelope_hash"] = self.envelope_hash
        return result


@dataclass(frozen=True)
class RuleResult:
    rule_id: str
    ok: bool
    reason: str

    def to_dict(self) -> dict[str, object]:
        return {"rule_id": self.rule_id, "ok": self.ok, "reason": self.reason}


_REGISTRATIONS: dict[tuple[str, str], EvidenceKindRegistration] = {}


def register_evidence_kind(registration: EvidenceKindRegistration) -> None:
    if not registration.kind or not registration.version:
        raise EvidenceError("schema_invalid", "evidence registration requires kind and version")
    key = (registration.kind, registration.version)
    if key in _REGISTRATIONS:
        raise EvidenceError("schema_invalid", f"duplicate_evidence_kind:{registration.kind}@{registration.version}")
    _REGISTRATIONS[key] = registration


def register_provider_evidence_kind(registration: EvidenceKindRegistration) -> None:
    """Bind a provider validator to a reserved extension slot exactly once."""
    if not registration.kind or not registration.version or registration.validator is None:
        raise EvidenceError("schema_invalid", "provider evidence registration requires a validator")
    key = (registration.kind, registration.version)
    existing = _REGISTRATIONS.get(key)
    if existing is None:
        _REGISTRATIONS[key] = registration
        return
    if existing.validator is not None:
        raise EvidenceError("schema_invalid", f"duplicate_evidence_kind:{registration.kind}@{registration.version}")
    _REGISTRATIONS[key] = registration


def evidence_registration(kind: str, version: str) -> EvidenceKindRegistration:
    registration = _REGISTRATIONS.get((kind, version))
    if registration is None:
        raise EvidenceError("schema_invalid", f"unsupported_evidence_kind:{kind}@{version}")
    return registration


def _register_builtins() -> None:
    registrations = {
        "git_state": "git-state@1",
        "artifact_hashes": "artifact-hashes@1",
        "command_result": "command-result@1",
        "review_result": "review-result@1",
        "github_state": "github-state@1",
        "authorization_event": "authorization-event@1",
        "cleanup_state": "cleanup-state@1",
        "integration_state": "integration-state@1",
        "package_provenance": "package-provenance@1",
        "installation_state": "installation-state@1",
        "agent_trial": "agent-trial@1",
        "workspace_receipt": "registered-evidence@1",
    }
    for kind, collector in registrations.items():
        register_evidence_kind(EvidenceKindRegistration(kind, collector.rsplit("@", 1)[1]))


_register_builtins()


def build_envelope_hash(envelope: Mapping[str, object]) -> HashRef:
    unsigned = dict(envelope)
    unsigned.pop("envelope_hash", None)
    return hash_ref(unsigned)


def _parse_envelope(data: Mapping[str, object], repo_root: Path) -> EvidenceEnvelope:
    _keys(
        data,
        {"schema_version", "gate", "repository", "workflow", "source", "target", "evidence", "prior_event_hash", "envelope_hash"},
        "envelope",
    )
    if data["schema_version"] != 1 or isinstance(data["schema_version"], bool):
        raise EvidenceError("schema_invalid", "unsupported schema version")
    gate = _string(data["gate"], "gate")
    assert gate is not None
    if gate not in SUPPORTED_GATES:
        raise EvidenceError("schema_invalid", f"unsupported gate:{gate}")

    active_root = repo_root.resolve()
    repository = _mapping(data["repository"], "repository")
    _keys(repository, {"root", "git_common_dir", "remote_identity"}, "repository")
    declared_root = _canonical_path(repository["root"], "repository.root")
    if declared_root != active_root:
        raise EvidenceError("repository_mismatch", "repository root does not match active repository")
    declared_common = _canonical_path(repository["git_common_dir"], "repository.git_common_dir")
    if declared_common != _expected_git_common_dir(active_root):
        raise EvidenceError("repository_mismatch", "git common directory does not match active repository")
    _string(repository["remote_identity"], "repository.remote_identity", allow_none=True)

    workflow = _mapping(data["workflow"], "workflow")
    _keys(workflow, {"run_id", "candidate_id", "mode", "authorization_hash"}, "workflow")
    _string(workflow["run_id"], "workflow.run_id")
    _string(workflow["candidate_id"], "workflow.candidate_id")
    mode = _string(workflow["mode"], "workflow.mode")
    if mode not in {"manual", "auto", "looping"}:
        raise EvidenceError("schema_invalid", "workflow.mode is unsupported")
    _hash(workflow["authorization_hash"], "workflow.authorization_hash")

    source = _mapping(data["source"], "source")
    _keys(source, {"spec_path", "spec_hash", "plan_path", "plan_hash"}, "source")
    spec_path = _repo_relative_path(source["spec_path"], active_root, "source.spec_path", allow_none=True)
    _hash(source["spec_hash"], "source.spec_hash", allow_none=True)
    plan_path = _repo_relative_path(source["plan_path"], active_root, "source.plan_path")
    plan_hash = _hash(source["plan_hash"], "source.plan_hash")
    assert plan_path is not None and plan_hash is not None
    if hash_bytes_ref((active_root / plan_path).read_bytes()) != plan_hash:
        raise EvidenceError("artifact_hash_mismatch", "source.plan_hash does not match active plan")
    if spec_path is None:
        if source["spec_hash"] is not None:
            raise EvidenceError("schema_invalid", "source.spec_hash requires source.spec_path")
    else:
        spec_hash = _hash(source["spec_hash"], "source.spec_hash")
        assert spec_hash is not None
        if hash_bytes_ref((active_root / spec_path).read_bytes()) != spec_hash:
            raise EvidenceError("artifact_hash_mismatch", "source.spec_hash does not match active spec")

    target = _mapping(data["target"], "target")
    target_keys = set(target)
    base_target_keys = {"task_id", "workspace_id", "branch"}
    merge_target_keys = base_target_keys | {"merge_strategy"}
    simple_isolation_target_keys = base_target_keys | {"isolation_required"}
    simple_isolation_merge_target_keys = simple_isolation_target_keys | {"merge_strategy"}
    isolation_target_keys = base_target_keys | {"isolation_required", "workspace_provider", "workspace_thread_id", "workspace_owner", "cleanup_actor"}
    isolation_merge_target_keys = isolation_target_keys | {"merge_strategy"}
    if target_keys not in (base_target_keys, merge_target_keys, simple_isolation_target_keys, simple_isolation_merge_target_keys, isolation_target_keys, isolation_merge_target_keys):
        raise EvidenceError("schema_invalid", "target keys are invalid")
    _string(target["task_id"], "target.task_id", allow_none=True)
    _string(target["workspace_id"], "target.workspace_id")
    _string(target["branch"], "target.branch")
    if "isolation_required" in target and not isinstance(target["isolation_required"], bool):
        raise EvidenceError("schema_invalid", "target.isolation_required must be boolean")
    if gate in {"premerge", "merge_decision"}:
        if "merge_strategy" not in target:
            raise EvidenceError("schema_invalid", "premerge and merge-decision targets must bind merge_strategy")
        _string(target["merge_strategy"], "target.merge_strategy")
    if target.get("isolation_required") is True:
        if target_keys not in (isolation_target_keys, isolation_merge_target_keys):
            raise EvidenceError("schema_invalid", "isolated target must bind provider, thread, owner, and cleanup actor")
        for field in ("workspace_provider", "workspace_thread_id", "workspace_owner", "cleanup_actor"):
            _string(target[field], f"target.{field}")
    elif target_keys in (isolation_target_keys, isolation_merge_target_keys):
        raise EvidenceError("schema_invalid", "workspace isolation bindings require isolation_required")

    raw_evidence = data["evidence"]
    if not isinstance(raw_evidence, list):
        raise EvidenceError("schema_invalid", "evidence must be an array")
    parsed_items: list[EvidenceItem] = []
    for index, raw_item in enumerate(raw_evidence):
        item = _mapping(raw_item, f"evidence[{index}]")
        _keys(item, {"kind", "collector", "observed_at", "payload_hash", "payload"}, f"evidence[{index}]")
        kind = _string(item["kind"], f"evidence[{index}].kind")
        collector = _string(item["collector"], f"evidence[{index}].collector")
        observed_at = _string(item["observed_at"], f"evidence[{index}].observed_at")
        assert kind is not None and collector is not None and observed_at is not None
        if not TIMESTAMP_PATTERN.fullmatch(observed_at):
            raise EvidenceError("schema_invalid", f"evidence[{index}].observed_at is not RFC3339")
        try:
            datetime.fromisoformat(observed_at[:-1] + "+00:00")
        except ValueError as exc:
            raise EvidenceError("schema_invalid", f"evidence[{index}].observed_at is not a real timestamp") from exc
        registration = evidence_registration(kind, collector.rsplit("@", 1)[-1] if "@" in collector else "")
        expected_collector = f"{registration.kind.replace('_', '-') if registration.kind != 'workspace_receipt' else 'registered-evidence'}@{registration.version}"
        if collector != expected_collector:
            raise EvidenceError("collector_untrusted", f"collector does not match evidence kind:{kind}")
        payload = _mapping(item["payload"], f"evidence[{index}].payload")
        payload_hash = _hash(item["payload_hash"], f"evidence[{index}].payload_hash")
        assert payload_hash is not None
        if hash_ref(payload) != payload_hash:
            raise EvidenceError("schema_invalid", f"evidence[{index}].payload_hash mismatch")
        if registration.validator is not None:
            registration.validator(payload)
        parsed_items.append(EvidenceItem(kind, collector, observed_at, HashRef(payload_hash), payload))

    prior = _hash(data["prior_event_hash"], "prior_event_hash", allow_none=True)
    envelope_hash = _hash(data["envelope_hash"], "envelope_hash")
    assert envelope_hash is not None
    if build_envelope_hash(data) != envelope_hash:
        raise EvidenceError("schema_invalid", "envelope_hash mismatch")
    return EvidenceEnvelope(
        schema_version=1,
        gate=gate,
        repository=repository,
        workflow=workflow,
        source=source,
        target=target,
        evidence=tuple(parsed_items),
        prior_event_hash=HashRef(prior) if prior is not None else None,
        envelope_hash=HashRef(envelope_hash),
    )


def parse_envelope_json(text: str, repo_root: Path) -> EvidenceEnvelope:
    try:
        data = json.loads(text, object_pairs_hook=_strict_pairs)
    except EvidenceError:
        raise
    except (json.JSONDecodeError, TypeError) as exc:
        raise EvidenceError("schema_invalid", f"invalid JSON: {exc}") from exc
    if not isinstance(data, Mapping):
        raise EvidenceError("schema_invalid", "envelope must be a JSON object")
    return _parse_envelope(data, Path(repo_root))


def parse_envelope(value: Mapping[str, object] | str, repo_root: Path) -> EvidenceEnvelope:
    if isinstance(value, str):
        return parse_envelope_json(value, repo_root)
    if not isinstance(value, Mapping):
        raise EvidenceError("schema_invalid", "envelope must be a JSON object")
    return _parse_envelope(value, Path(repo_root))
