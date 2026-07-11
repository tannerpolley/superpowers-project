"""Observed-event metrics shared by the agent usability runner and tests."""
from __future__ import annotations

from collections.abc import Mapping, Sequence


def summarize_observed_events(events: Sequence[Mapping[str, object]]) -> dict[str, object]:
    return {
        "tool_calls": sum(event.get("kind") == "tool_call" for event in events),
        "external_mutations": sum(event.get("kind") == "external_mutation" for event in events),
        "receipt_identities": [
            event["receipt_hash"]
            for event in events
            if event.get("kind") == "receipt" and isinstance(event.get("receipt_hash"), str)
        ],
    }
