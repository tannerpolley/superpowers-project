"""Read-only collectors that construct repository-bound evidence."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import os
import re
from pathlib import Path
import subprocess
from typing import Mapping, Sequence

try:
    from .agent_usability import validate_trial_set
    from .command_support import resolve_under
    from .evidence_schema import EvidenceError, evidence_registration, hash_bytes_ref, hash_ref, build_envelope_hash, parse_envelope
    from .package_provenance import runtime_contract_hash, runtime_manifest
except ImportError:  # pragma: no cover - CLI loads scripts/lib as a top-level path
    from agent_usability import validate_trial_set
    from command_support import resolve_under
    from evidence_schema import EvidenceError, evidence_registration, hash_bytes_ref, hash_ref, build_envelope_hash, parse_envelope
    from package_provenance import runtime_contract_hash, runtime_manifest


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
    "source_validation": ("bash", "./scripts/validate.sh"),
    "sync_live_validation": ("bash", "./scripts/sync-live.sh", "--validate"),
}
READ_ONLY_COMMAND_TIMEOUTS: dict[str, int] = {
    "unit_command_registry": 60,
    "runtime_package_validation": 60,
    "source_validation": 180,
    "sync_live_validation": 60,
}
DEFAULT_INSTALLATION_ROOT = Path.home() / ".codex" / "plugins" / "superpowers-project"
DEFAULT_TRIAL_ROOT_NAME = Path(".superpowers") / "runs"
TRUSTED_PROVIDER_COMMANDS: dict[str, tuple[str, ...]] = {
    "github_pr_state": ("gh", "pr", "view", "--json", "number,baseRefName,headRefName,headRefOid,mergeable,reviews,reviewDecision,statusCheckRollup"),
    "github_repository": ("gh", "repo", "view", "--json", "id,nameWithOwner"),
}


def _observe_process(root: Path, argv: Sequence[str], timeout: int = 15) -> dict[str, object]:
    command = [str(part) for part in argv]
    try:
        environment = os.environ.copy()
        if command == list(READ_ONLY_COMMANDS["sync_live_validation"]):
            environment["SUPERPOWERS_READ_ONLY_COLLECTION"] = "1"
        result = subprocess.run(
            command,
            cwd=root,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=False,
            env=environment,
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


def _strict_json_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError("provider_state_unavailable", f"duplicate provider observation key:{key}")
        result[key] = value
    return result


def _normalize_github_state(raw: Mapping[str, object], repository: Mapping[str, object], base_sha: object) -> dict[str, object]:
    checks = raw.get("checks")
    if not isinstance(checks, list):
        checks = raw.get("statusCheckRollup", [])
    normalized_checks = []
    if isinstance(checks, list):
        for item in checks:
            if isinstance(item, Mapping):
                conclusion = item.get("conclusion") or item.get("state")
                normalized_checks.append({"name": item.get("name") or item.get("context"), "conclusion": conclusion.lower() if isinstance(conclusion, str) else conclusion})
    mergeable = raw.get("mergeable") is True or raw.get("mergeable") == "MERGEABLE"
    return {
        "provider_available": True,
        "pr_id": raw.get("pr_id", raw.get("number")),
        "repository": repository.get("nameWithOwner"),
        "repository_id": repository.get("id"),
        "base_ref": raw.get("base_ref", raw.get("baseRefName")),
        "base_sha": base_sha,
        "head_ref": raw.get("head_ref", raw.get("headRefName")),
        "head_sha": raw.get("head_sha", raw.get("headRefOid")),
        "source_branch": raw.get("source_branch", raw.get("headRefName")),
        "source_sha": raw.get("source_sha", raw.get("headRefOid")),
        "mergeable": mergeable,
        "reviews": raw.get("reviews", []),
        "review_decision": raw.get("reviewDecision"),
        "checks": normalized_checks,
    }


def collect_github_state(root: Path, observation_id: str = "github_pr_state") -> CollectorResult:
    command = TRUSTED_PROVIDER_COMMANDS.get(observation_id)
    if command is None:
        raise EvidenceError("collector_untrusted", f"unsupported provider observation:{observation_id}")
    pr_observation = _observe_process(Path(root).resolve(), command, 30)
    repository_observation = _observe_process(Path(root).resolve(), TRUSTED_PROVIDER_COMMANDS["github_repository"], 30)
    if any(item["exit_code"] != 0 or item["timed_out"] is not False for item in (pr_observation, repository_observation)):
        payload = {
            "provider_available": False,
            "observation_id": observation_id,
            "observation_hash": hash_ref({"pr": pr_observation["stdout_hash"], "repository": repository_observation["stdout_hash"]}),
            "error_hash": hash_ref({"pr": pr_observation["stderr_hash"], "repository": repository_observation["stderr_hash"]}),
        }
        return CollectorResult("github_state", "github-state@1", _observed_at(), payload)
    try:
        raw = json.loads(str(pr_observation["_stdout_text"]), object_pairs_hook=_strict_json_pairs)
        repository = json.loads(str(repository_observation["_stdout_text"]), object_pairs_hook=_strict_json_pairs)
        if not isinstance(raw, Mapping) or not isinstance(repository, Mapping):
            raise ValueError("provider observation must be an object")
        repository_name = repository.get("nameWithOwner")
        base_ref = raw.get("baseRefName")
        if not isinstance(repository_name, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository_name) or not isinstance(base_ref, str) or not re.fullmatch(r"[A-Za-z0-9._/-]+", base_ref) or base_ref.startswith("-"):
            raise ValueError("provider repository or base ref is invalid")
        base_command = ("gh", "api", f"repos/{repository_name}/git/ref/heads/{base_ref}")
        base_observation = _observe_process(Path(root).resolve(), base_command, 30)
        if base_observation["exit_code"] != 0 or base_observation["timed_out"] is not False:
            raise ValueError("base ref observation is unavailable")
        base_response = json.loads(str(base_observation["_stdout_text"]), object_pairs_hook=_strict_json_pairs)
        base_object = base_response.get("object") if isinstance(base_response, Mapping) else None
        base_sha = base_object.get("sha") if isinstance(base_object, Mapping) else None
        if not isinstance(base_sha, str) or not base_sha:
            raise ValueError("base ref observation has no SHA")
        payload = _normalize_github_state(raw, repository, base_sha)
        observation_hash = hash_ref({"pr": pr_observation["stdout_hash"], "repository": repository_observation["stdout_hash"], "base": base_observation["stdout_hash"]})
    except (ValueError, json.JSONDecodeError, TypeError) as exc:
        return CollectorResult("github_state", "github-state@1", _observed_at(), {"provider_available": False, "observation_id": observation_id, "observation_hash": hash_ref({"pr": pr_observation["stdout_hash"], "repository": repository_observation["stdout_hash"]}), "error": str(exc)})
    payload["observation_id"] = observation_id
    payload["observation_hash"] = observation_hash
    return CollectorResult("github_state", "github-state@1", _observed_at(), payload)


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


def _package_observation(root: Path, observation_id: str) -> CollectorResult:
    if observation_id != "package_current":
        raise EvidenceError("collector_untrusted", f"unsupported package observation:{observation_id}")
    manifest_path = Path(root) / ".codex-plugin" / "plugin.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    head = _observe_process(Path(root), READ_ONLY_COMMANDS["git_head"])
    entries = [entry.to_dict() for entry in runtime_manifest(Path(root))]
    payload = {
        "observation_id": observation_id,
        "package_hash": hash_ref(entries),
        "contract_hash": runtime_contract_hash(Path(root)),
        "manifest_version": manifest.get("version"),
        "commit": str(head["_stdout_text"]).strip() if head["exit_code"] == 0 else "",
        "revision_classification": "runtime",
        "modes": {entry["path"]: entry["mode"] for entry in entries},
    }
    return CollectorResult("package_provenance", "package-provenance@1", _observed_at(), payload)


def collect_package_provenance(root: Path, observation_id: str = "package_current") -> CollectorResult:
    try:
        return _package_observation(Path(root).resolve(), observation_id)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise EvidenceError("provider_state_unavailable", f"package observation is unavailable: {exc}") from exc


def collect_installation_state(root: Path, observation_id: str = "installation_current", installation_root: Path | None = None) -> CollectorResult:
    if observation_id != "installation_current":
        raise EvidenceError("collector_untrusted", f"unsupported installation observation:{observation_id}")
    live_root = Path(installation_root or DEFAULT_INSTALLATION_ROOT).expanduser().resolve()
    try:
        manifest = json.loads((live_root / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
        entries = [entry.to_dict() for entry in runtime_manifest(live_root)]
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise EvidenceError("provider_state_unavailable", f"installation observation is unavailable: {exc}") from exc
    payload = {
        "observation_id": observation_id,
        "installation_root": str(live_root),
        "installed_package_hash": hash_ref(entries),
        "installed_contract_hash": runtime_contract_hash(live_root),
        "manifest_version": manifest.get("version"),
        "current_version": manifest.get("version"),
        "modes": {entry["path"]: entry["mode"] for entry in entries},
    }
    return CollectorResult("installation_state", "installation-state@1", _observed_at(), payload)


def collect_agent_trial(root: Path, observation_id: str = "agent_trials_current", receipt_root: Path | None = None) -> CollectorResult:
    if observation_id != "agent_trials_current":
        raise EvidenceError("collector_untrusted", f"unsupported agent trial observation:{observation_id}")
    root = Path(root).resolve()
    directory = (Path(receipt_root) if receipt_root is not None else root / DEFAULT_TRIAL_ROOT_NAME).resolve()
    try:
        directory.relative_to(root)
    except ValueError as exc:
        raise EvidenceError("repository_mismatch", "agent trial receipt root escapes the repository") from exc
    receipt_paths = sorted(directory.glob("**/receipt.json")) if directory.is_dir() else []
    if not receipt_paths:
        raise EvidenceError("provider_state_unavailable", "agent trial receipts are unavailable")
    try:
        receipts = [json.loads(path.read_text(encoding="utf-8")) for path in receipt_paths]
        metrics = validate_trial_set(receipts, root)
    except Exception as exc:
        raise EvidenceError("provider_state_unavailable", f"agent trial receipts are unauthenticated: {exc}") from exc
    tool_calls: list[dict[str, object]] = []
    external_mutations = 0
    scenarios: list[str] = []
    for path, receipt in zip(receipt_paths, receipts):
        scenarios.append(str(receipt.get("scenario", "")))
        external_mutations += int(receipt.get("external_mutations", 0))
        project_value = receipt.get("project_root")
        project_root = Path(str(project_value)) if isinstance(project_value, str) else root
        if not project_root.is_absolute():
            project_root = root / project_root
        ledger_value = (receipt.get("event_ledger") or {}).get("path")
        ledger_path = Path(str(ledger_value)) if isinstance(ledger_value, str) else Path("missing")
        if not ledger_path.is_absolute():
            ledger_path = project_root / ledger_path
        if not ledger_path.is_file():
            raise EvidenceError("provider_state_unavailable", f"agent trial event ledger is missing: {path}")
        for line in ledger_path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                event = json.loads(line)
                if isinstance(event, Mapping):
                    tool_calls.append({"receipt": path.relative_to(root).as_posix(), "type": event.get("type"), "hash": event.get("hash")})
    payload = {
        "observation_id": observation_id,
        "receipt_root": str(directory),
        "package_hash": hash_ref([entry.to_dict() for entry in runtime_manifest(root)]),
        "tool_calls": tool_calls,
        "external_mutations": external_mutations,
        "receipt_hashes": [hash_bytes_ref(path.read_bytes()) for path in receipt_paths],
        "scenarios": scenarios,
        "metrics": metrics,
    }
    return CollectorResult("agent_trial", "agent-trial@1", _observed_at(), payload)


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
    "package_provenance": ("package-provenance@1", collect_package_provenance),
    "installation_state": ("installation-state@1", collect_installation_state),
    "agent_trial": ("agent-trial@1", collect_agent_trial),
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
    provider_inputs = request.provider_inputs
    for command_id in request.commands:
        if command_id == "sync_live_validation" and isinstance(provider_inputs.get("installation_root"), str):
            previous_live_root = os.environ.get("SUPERPOWERS_LIVE_PLUGIN_ROOT")
            os.environ["SUPERPOWERS_LIVE_PLUGIN_ROOT"] = str(provider_inputs["installation_root"])
            try:
                results.append(collect_command_result(root, command_id))
            finally:
                if previous_live_root is None:
                    os.environ.pop("SUPERPOWERS_LIVE_PLUGIN_ROOT", None)
                else:
                    os.environ["SUPERPOWERS_LIVE_PLUGIN_ROOT"] = previous_live_root
        else:
            results.append(collect_command_result(root, command_id))
    reviews = provider_inputs.get("reviews")
    if reviews is not None:
        results.append(collect_review_result({"reviews": reviews}))
    if isinstance(provider_inputs.get("github_observation_id"), str):
        results.append(collect_github_state(root, str(provider_inputs["github_observation_id"])))
    elif "github" in provider_inputs or "github_observation" in provider_inputs:
        raise EvidenceError("collector_untrusted", "caller-wrapped GitHub JSON is unsupported")
    authorization = provider_inputs.get("authorization")
    if not isinstance(authorization, Mapping):
        raise EvidenceError("evidence_missing", "authorization observation is required")
    results.append(collect_authorization_event(authorization))
    cleanup_actor = request.target.get("cleanup_actor")
    results.append(collect_cleanup_state(root, cleanup_actor if isinstance(cleanup_actor, str) else None))
    if request.gate == "publish_ready":
        forbidden = {"package", "installation", "agent_trial"} & set(provider_inputs)
        if forbidden:
            raise EvidenceError("collector_untrusted", "caller-supplied package, installation, and trial payloads are unsupported")
        package_id = provider_inputs.get("package_observation_id")
        installation_id = provider_inputs.get("installation_observation_id")
        trial_id = provider_inputs.get("agent_trial_observation_id")
        if not all(isinstance(value, str) for value in (package_id, installation_id, trial_id)):
            raise EvidenceError("evidence_missing", "trusted package, installation, and agent-trial observation IDs are required")
        results.extend([
            collect_package_provenance(root, str(package_id)),
            collect_installation_state(root, str(installation_id), Path(str(provider_inputs["installation_root"])) if isinstance(provider_inputs.get("installation_root"), str) else None),
            collect_agent_trial(root, str(trial_id), resolve_under(root, str(provider_inputs["agent_trial_receipt_dir"]), "agent_trial_receipt_dir") if isinstance(provider_inputs.get("agent_trial_receipt_dir"), str) else None),
        ])
    for key, kind in (("integration", "integration_state"),):
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
