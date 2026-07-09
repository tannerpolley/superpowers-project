from dataclasses import dataclass
from pathlib import Path


class ContextError(ValueError):
    pass


@dataclass(frozen=True)
class RuntimeContext:
    script_path: Path
    plugin_root: Path
    invocation_cwd: Path
    script_rel: str


def _under(root: Path, value: str, label: str) -> Path:
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = root / candidate
    resolved = candidate.resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        scope = "project" if "project" in label else "plugin"
        raise ContextError(f"{label}: {resolved} is outside {scope} root") from exc
    return resolved


def resolve_project_root(ctx: RuntimeContext, args) -> Path:
    value = args.get("RepoRoot") or args.get("repo_root")
    if value is None:
        return ctx.invocation_cwd.resolve()
    root = Path(value)
    if not root.is_absolute():
        root = ctx.invocation_cwd / root
    return root.resolve()


def resolve_project_path(project_root: Path, value: str, label: str = "path") -> Path:
    try:
        return _under(project_root, value, f"{label} outside project root")
    except ContextError as exc:
        raise ContextError(str(exc)) from exc


def resolve_plugin_path(plugin_root: Path, value: str, label: str = "path") -> Path:
    return _under(plugin_root, value, f"{label} outside plugin root")
