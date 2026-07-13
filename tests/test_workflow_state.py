from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.workflow_state import WorkflowStateError, append_event, replay_events


CHECKPOINT = {
    "type": "budget_rechecked",
    "candidate": "one",
    "evidence": {
        "budget_path": "budget.json",
        "budget_hash": "a" * 64,
        "health_path": "health.json",
        "health_hash": "b" * 64,
    },
}
ITERATION = (
    {"type": "run_started", "run_id": "trial"},
    {"type": "candidate_selected", "candidate": "one"},
    {"type": "candidate_accepted", "candidate": "one"},
    {"type": "verifier_passed", "candidate": "one"},
    CHECKPOINT,
    {"type": "continuation_granted", "candidate": "one"},
)


class WorkflowStateTests(unittest.TestCase):
    def append(self, root: Path, events) -> None:
        for event in events:
            append_event(root, event)

    def assert_rejected(self, events, rejected, pattern: str) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.append(root, events)
            with self.assertRaisesRegex(WorkflowStateError, pattern):
                append_event(root, rejected)

    def test_hash_chain_replays_projection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.append(root, (*ITERATION, {"type": "candidate_selected", "candidate": "two"}))
            projection = replay_events(root / "events.jsonl")
            self.assertEqual(("two", 7), (projection.selected_candidate, projection.events))
            self.assertEqual(projection.as_dict(), json.loads((root / "run.json").read_text()))

    def test_invalid_transition_order_fails_closed(self):
        cases = (
            (
                ({"type": "run_started", "run_id": "terminal"}, {"type": "run_stopped", "reason": "done"}),
                {"type": "run_stopped", "reason": "late"},
                "already stopped",
            ),
            (
                ({"type": "run_started", "run_id": "second"}, {"type": "candidate_selected", "candidate": "one"}),
                {"type": "candidate_selected", "candidate": "two"},
                "second candidate",
            ),
            (
                ({"type": "run_started", "run_id": "repeat"}, {"type": "candidate_selected", "candidate": "one"}),
                {"type": "candidate_selected", "candidate": "one"},
                "already selected",
            ),
            (
                (*ITERATION, {"type": "candidate_selected", "candidate": "two"}),
                {"type": "candidate_selected", "candidate": "one"},
                "already selected",
            ),
            (
                ({"type": "run_started", "run_id": "order"}, {"type": "candidate_selected", "candidate": "one"},
                 CHECKPOINT, {"type": "mutation_applied", "candidate": "one"}),
                {"type": "continuation_granted", "candidate": "one"},
                "immediately follow",
            ),
        )
        for events, rejected, pattern in cases:
            with self.subTest(pattern=pattern):
                self.assert_rejected(events, rejected, pattern)

    def test_tampering_and_malformed_events_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial"})
            path = root / "events.jsonl"
            record = json.loads(path.read_text())
            record["run_id"] = "forged"
            path.write_text(json.dumps(record) + "\n")
            with self.assertRaisesRegex(WorkflowStateError, "hash"):
                replay_events(path)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(WorkflowStateError):
                append_event(root, {"type": "unknown"})
            (root / "events.jsonl").write_text("{}\n")
            with self.assertRaises(WorkflowStateError):
                replay_events(root / "events.jsonl")


if __name__ == "__main__":
    unittest.main()
