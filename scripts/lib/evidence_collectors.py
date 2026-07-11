"""Read-only collectors that construct repository-bound evidence."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import subprocess
from typing import Mapping, Sequence

try:
    from .command_support import resolve_under
    from .evidence_schema import EvidenceError, evidence_registration, hash_bytes_ref, hash_ref, build_envelope_hash, parse_envelope
except ImportError:  # pragma: no cover - CLI loads scripts/lib as a top-level path
    from command_support import resolve_under
    from evidence_schema import EvidenceError, evidence_registration, hash_bytes_ref, hash_ref, build_envelope_hash, parse_envelope


def _observed_at() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


READ_ONLY_COMMANDS: dict[str, tuple[str, ...]] = {
    "git_status": ("git", "status", "--short"),
    "git_head": ("git", "rev-parse", "HEAD"),
    "git_branch": ("git", "branch", "--show-current"),
    "git_common_dir": ("git", "rev-parse", "--git-common-dir"),
    "git_remote_origin": ("git", "remote", "get-url", "origin"),
    "git_missing_ref": ("git", "rev-parse", "missing-ref"),
    "unit_command_registry": ("python3", "-m", "unittest", "tests.test_command_registry"),
    "runtime_package_validation": ("python3", "scripts/validate-runtime-package.py", "--repo-root", "."),
}
READ_ONLY_COMMAND_TIMEOUTS: dict[str, int] = {
    "unit_command_registry": 60,
    "runtime_package_validation": 60,
}


def _observe_process(root: Path, argv: Sequence[str], timeout: int = 15) -> dict[str, object]:
    command = [str(part) for part in argv]
    try:
        result = subprocess.run(
            command,
            cwd=root,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=False,
            timeout=timeout,
            check=False,
        )
        stdout = result.stdout or b""
        stderr = result.stderr or b""
        return {
            "argv": command,
            "exit_code": result.returncode,
            "stdout_hash": hash_bytes_ref(stdout),
            "stderr_hash": hash_bytes_ref(stderr),
            "timed_out": False,
            "_stdout_text": stdout.decode("utf-8", errors="replace"),
            "_stderr_text": stderr.decode("utf-8", errors="replace"),
        }
    except subprocess.TimeoutExpired as exc:
        stdout = (exc.stdout or b"") if isinstance(exc.stdout, bytes) else str(exc.stdout or "").encode()
        stderr = (exc.stderr or b"") if isinstance(exc.stderr, bytes) else str(exc.stderr or "").encode()
        return {
            "argv": command,
            "exit_code": None,
            "stdout_hash": hash_bytes_ref(stdout),
            "stderr_hash": hash_bytes_ref(stderr),
            "timed_out": True,
            "_stdout_text": stdout.decode("utf-8", errors="replace"),
            "_stderr_text": stderr.decode("utf-8", errors="replace"),
        }
    except OSError as exc:
        return {
            "argv": command,
            "exit_code": None,
            "stdout_hash": hash_bytes_ref(b""),
            "stderr_hash": hash_ref({"error": type(exc).__name__, "message": str(exc)}),
            "timed_out": False,
            "_stdout_text": "",
            "_stderr_text": str(exc),
        }


@dataclass(frozen=True)
class CollectorResult:
    kind: str
    collector: str
    observed_at: str
    payload: Mapping[str, object]

    def to_evidence(self) -> dict[str, object]:
        return {
            "kind": self.kind,
            "collector": self.collector,
            "observed_at": self.observed_at,
            "payload_hash": hash_ref(self.payload),
            "payload": dict(self.payload),
        }


@dataclass(frozen=True)
class CollectionRequest:
    gate: str
    repository_root: Path
    workflow: Mapping[str, object]
    source: Mapping[str, object]
    target: Mapping[str, object]
    commands: Sequence[str]
    provider_inputs: Mapping[str, object]
    prior_event_hash: str | None = None

    @classmethod
    def from_mapping(cls, data: Mapping[str, object], repository_root: Path) -> "CollectionRequest":
        allowed = {"gate", "workflow", "source", "target", "commands", "provider_inputs", "prior_event_hash"}
        unknown = set(data) - allowed
        missing = {"gate", "workflow", "source", "target", "commands", "provider_inputs"} - set(data)
        if unknown or missing:
            details = []
            if unknown:
                details.append("unknown=" + ",".join(sorted(unknown)))
            if missing:
                details.append("missing=" + ",".join(sorted(missing)))
            raise EvidenceError("schema_invalid", "collection request keys invalid: " + "; ".join(details))
        if not isinstance(data["workflow"], Mapping) or not isinstance(data["source"], Mapping) or not isinstance(data["target"], Mapping) or not isinstance(data["provider_inputs"], Mapping):
            raise EvidenceError("schema_invalid", "collection request nested fields must be objects")
        if not isinstance(data["commands"], list):
            raise EvidenceError("schema_invalid", "collection request commands must be an array")
        commands: list[str] = []
        for command in data["commands"]:
            if not isinstance(command, str) or command not in READ_ONLY_COMMANDS:
                raise EvidenceError("collector_untrusted", f"unsupported read-only command:{command}")
            commands.append(command)
        return cls(
            gate=str(data["gate"]),
            repository_root=repository_root,
            workflow=data["workflow"],
            source=data["source"],
            target=data["target"],
            commands=tuple(commands),
            provider_inputs=data["provider_inputs"],
            prior_event_hash=data.get("prior_event_hash") if data.get("prior_event_hash") is None or isinstance(data.get("prior_event_hash"), str) else str(data.get("prior_event_hash")),
        )


def collect_git_state(root: Path) -> CollectorResult:
    root = Path(root).resolve()
    status = _observe_process(root, READ_ONLY_COMMANDS["git_status"])
    head = _observe_process(root, READ_ONLY_COMMANDS["git_head"])
    branch = _observe_process(root, READ_ONLY_COMMANDS["git_branch"])
    common = _observe_process(root, READ_ONLY_COMMANDS["git_common_dir"])
    remote = _observe_process(root, READ_ONLY_COMMANDS["git_remote_origin"])
    payload = {
        "status_exit_code": status["exit_code"],
        "status_stdout_hash": status["stdout_hash"],
        "head": str(head["_stdout_text"]).strip() if head["exit_code"] == 0 else "",
        "branch": str(branch["_stdout_text"]).strip() if branch["exit_code"] == 0 else "",
        "git_common_dir": _canonical_process_path(root, str(common["_stdout_text"]).strip() if common["exit_code"] == 0 else ""),
        "remote_identity": _normalize_remote(str(remote["_stdout_text"]).strip() if remote["exit_code"] == 0 else ""),
    }
    return CollectorResult("git_state", "git-state@1", _observed_at(), payload)


def _canonical_process_path(root: Path, value: str) -> str:
    if not value:
        return str((root / ".git").resolve())
    path = Path(value)
    return str((root / path if not path.is_absolute() else path).resolve())


def _normalize_remote(value: str) -> str | None:
    if not value:
        return None
    value = value.removesuffix(".git")
    if value.startswith("git@github.com:"):
        return value.removeprefix("git@github.com:")
    for prefix in ("https://github.com/", "http://github.com/"):
        if value.startswith(prefix):
            return value.removeprefix(prefix)
    return value


def collect_artifact_hashes(root: Path, paths: Sequence[str]) -> CollectorResult:
    root = Path(root).resolve()
    hashes: dict[str, str] = {}
    for value in paths:
        path = resolve_under(root, str(value), "artifact path")
        if not path.is_file() or path.is_symlink():
            raise EvidenceError("repository_mismatch", f"artifact path is not a regular file: {value}")
        hashes[path.relative_to(root).as_posix()] = hash_bytes_ref(path.read_bytes())
    return CollectorResult("artifact_hashes", "artifact-hashes@1", _observed_at(), {"paths": hashes, "count": len(hashes)})


def collect_command_result(root: Path, command_id: str) -> CollectorResult:
    if not isinstance(command_id, str) or command_id not in READ_ONLY_COMMANDS:
        raise EvidenceError("collector_untrusted", f"unsupported read-only command:{command_id}")
    observation = _observe_process(Path(root).resolve(), READ_ONLY_COMMANDS[command_id], READ_ONLY_COMMAND_TIMEOUTS.get(command_id, 15))
    payload = {key: value for key, value in observation.items() if not key.startswith("_")}
    payload["command_id"] = command_id
    return CollectorResult("command_result", "command-result@1", _observed_at(), payload)


def collect_review_result(review: Mapping[str, object]) -> CollectorResult:
    return CollectorResult("review_result", "review-result@1", _observed_at(), dict(review))


def collect_github_state(raw_json: Mapping[str, object]) -> CollectorResult:
    return CollectorResult("github_state", "github-state@1", _observed_at(), dict(raw_json))


def collect_authorization_event(event: Mapping[str, object]) -> CollectorResult:
    payload = {"event": dict(event), "event_hash": hash_ref(event)}
    return CollectorResult("authorization_event", "authorization-event@1", _observed_at(), payload)


def collect_cleanup_state(root: Path, cleanup_actor: str | None = None) -> CollectorResult:
    observation = _observe_process(Path(root).resolve(), ["git", "status", "--short"])
    payload: dict[str, object] = {
        "status_exit_code": observation["exit_code"],
        "status_hash": observation["stdout_hash"],
        "task_owned_paths": [],
    }
    if cleanup_actor is not None:
        payload["cleanup_actor"] = cleanup_actor
    return CollectorResult(
        "cleanup_state",
        "cleanup-state@1",
        _observed_at(),
        payload,
    )


def collect_registered_evidence(kind: str, provider_receipt: Mapping[str, object]) -> CollectorResult:
    registration = evidence_registration(kind, "1")
    if registration.validator is not None:
        registration.validator(provider_receipt)
    collector = "registered-evidence@1"
    return CollectorResult(kind, collector, _observed_at(), dict(provider_receipt))


COLLECTORS = {
    "git_state": ("git-state@1", collect_git_state),
    "artifact_hashes": ("artifact-hashes@1", collect_artifact_hashes),
    "command_result": ("command-result@1", collect_command_result),
    "review_result": ("review-result@1", collect_review_result),
    "github_state": ("github-state@1", collect_github_state),
    "authorization_event": ("authorization-event@1", collect_authorization_event),
    "cleanup_state": ("cleanup-state@1", collect_cleanup_state),
    "workspace_receipt": ("registered-evidence@1", collect_registered_evidence),
}


def build_evidence_envelope(request: CollectionRequest) -> dict[str, object]:
    root = Path(request.repository_root).resolve()
    git_result = collect_git_state(root)
    source = dict(request.source)
    spec_path = source.get("spec_path")
    plan_path = source.get("plan_path")
    if not isinstance(plan_path, str) or not plan_path:
        raise EvidenceError("schema_invalid", "collection source.plan_path is required")
    plan = resolve_under(root, plan_path, "source.plan_path")
    source["spec_path"] = spec_path if isinstance(spec_path, str) and spec_path else None
    source["spec_hash"] = hash_bytes_ref(resolve_under(root, spec_path, "source.spec_path").read_bytes()) if source["spec_path"] else None
    source["plan_hash"] = hash_bytes_ref(plan.read_bytes())
    results: list[CollectorResult] = [git_result]
    artifact_paths = [plan_path] + ([source["spec_path"]] if source["spec_path"] else [])
    results.append(collect_artifact_hashes(root, artifact_paths))
    for command_id in request.commands:
        results.append(collect_command_result(root, command_id))
    provider_inputs = request.provider_inputs
    reviews = provider_inputs.get("reviews")
    if reviews is not None:
        results.append(collect_review_result({"reviews": reviews}))
    if isinstance(provider_inputs.get("github"), Mapping):
        results.append(collect_github_state(provider_inputs["github"]))
    authorization = provider_inputs.get("authorization")
    if not isinstance(authorization, Mapping):
        raise EvidenceError("evidence_missing", "authorization observation is required")
    results.append(collect_authorization_event(authorization))
    cleanup_actor = request.target.get("cleanup_actor")
    results.append(collect_cleanup_state(root, cleanup_actor if isinstance(cleanup_actor, str) else None))
    for key, kind in (("integration", "integration_state"), ("package", "package_provenance"), ("installation", "installation_state"), ("agent_trial", "agent_trial")):
        if isinstance(provider_inputs.get(key), Mapping):
            registration = evidence_registration(kind, "1")
            results.append(CollectorResult(kind, registration.kind.replace("_", "-") + "@1", _observed_at(), dict(provider_inputs[key])))
    workspace = provider_inputs.get("workspace_receipt")
    if isinstance(workspace, Mapping):
        results.append(collect_registered_evidence("workspace_receipt", workspace))
    envelope: dict[str, object] = {
        "schema_version": 1,
        "gate": request.gate,
        "repository": {
            "root": str(root),
            "git_common_dir": git_result.payload["git_common_dir"],
            "remote_identity": git_result.payload["remote_identity"],
        },
        "workflow": dict(request.workflow),
        "source": source,
        "target": dict(request.target),
        "evidence": [result.to_evidence() for result in results],
        "prior_event_hash": request.prior_event_hash,
    }
    envelope["envelope_hash"] = build_envelope_hash(envelope)
    parse_envelope(envelope, root)
    return envelope
