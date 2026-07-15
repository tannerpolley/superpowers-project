"""Codex output contracts and observed metrics for installed-product trials."""
from __future__ import annotations

from collections.abc import Mapping, Sequence
import re


WORKER_SCHEMA = {
    "type": "object",
    "required": ["observed_outcome", "friction", "blocker", "source_urls", "observed_skill_root", "claim"],
    "properties": {
        "observed_outcome": {"enum": ["pass", "blocked", "fail"]},
        "friction": {"type": "integer", "minimum": 1, "maximum": 5},
        "blocker": {"type": ["string", "null"]},
        "source_urls": {"type": "array", "items": {"type": "string"}},
        "observed_skill_root": {"type": "string"},
        "claim": {
            "type": "object",
            "required": ["summary"],
            "properties": {"summary": {"type": "string"}},
            "additionalProperties": False,
        },
    },
    "additionalProperties": False,
}
VERIFIER_SCHEMA = {
    "type": "object",
    "required": ["decision", "reason"],
    "properties": {
        "decision": {"enum": ["pass", "blocked", "reject"]},
        "reason": {"type": "string"},
    },
    "additionalProperties": False,
}

_MUTATING_COMMAND = re.compile(
    r"\b(?:git\s+push|codex\s+plugin\s+(?:add|remove)|gh\s+(?:issue\s+(?:create|edit|close|reopen)|"
    r"pr\s+(?:create|merge|close|reopen)|repo\s+rename|api\b[^\n]*(?:-X|--method)\s*(?:POST|PUT|PATCH|DELETE))|"
    r"(?:curl|wget)\b[^\n]*(?:-X|--method)\s*"
    r"(?:POST|PUT|PATCH|DELETE))\b",
    re.I,
)
_MUTATING_TOOL = re.compile(r"(?:^|[._:-])(?:create|update|edit|delete|remove|close|reopen|merge|push|publish|send)(?:[._:-]|$)", re.I)
_TOOL_TYPES = {"command_execution", "file_change", "mcp_tool_call", "request_user_input", "web_search"}


def _tool_name(item: Mapping[str, object]) -> str:
    kind = str(item.get("type") or "")
    if kind == "mcp_tool_call":
        server = str(item.get("server") or "mcp")
        tool = str(item.get("tool") or item.get("name") or "unknown")
        return f"{server}.{tool}"
    return kind


def summarize_observed_events(events: Sequence[Mapping[str, object]]) -> dict[str, object]:
    tool_calls: list[str] = []
    user_input_calls = 0
    external_mutations = 0
    for event in events:
        if event.get("type") != "item.completed":
            continue
        item = event.get("item")
        if not isinstance(item, Mapping):
            continue
        kind = str(item.get("type") or "")
        if kind == "error" and "request_user_input" in str(item.get("message") or ""):
            tool_calls.append("request_user_input")
            user_input_calls += 1
            continue
        if kind not in _TOOL_TYPES:
            continue
        name = _tool_name(item)
        tool_calls.append(name)
        if kind == "request_user_input" or "request_user_input" in name:
            user_input_calls += 1
        command = item.get("command")
        command_text = " ".join(map(str, command)) if isinstance(command, Sequence) and not isinstance(command, str) else str(command or "")
        if (kind == "command_execution" and _MUTATING_COMMAND.search(command_text)) or (kind == "mcp_tool_call" and _MUTATING_TOOL.search(name)):
            external_mutations += 1
    return {"tool_calls": tool_calls, "user_input_calls": user_input_calls, "external_mutations": external_mutations}
