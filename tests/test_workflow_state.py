from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.workflow_state import WorkflowStateError, append_event, replay_events


class WorkflowStateTests(unittest.TestCase):
    def test_hash_chain_replays_projection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-1"})
            append_event(root, {"type": "candidate_selected", "candidate": "one"})
            append_event(root, {"type": "candidate_accepted", "candidate": "one"})
            append_event(root, {"type": "verifier_passed", "candidate": "one"})
            append_event(root, {
                "type": "budget_rechecked",
                "candidate": "one",
                "evidence": {
                    "budget_path": "budget.json",
                    "budget_hash": "a" * 64,
                    "health_path": "health.json",
                    "health_hash": "b" * 64,
                },
            })
            append_event(root, {"type": "continuation_granted", "candidate": "one"})
            append_event(root, {"type": "candidate_selected", "candidate": "two"})
            projection = replay_events(root / "events.jsonl")
            self.assertEqual(projection.selected_candidate, "two")
            self.assertEqual(projection.events, 7)
            self.assertEqual(projection.as_dict(), json.loads((root / "run.json").read_text()))

    def test_terminal_state_rejects_later_events(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-terminal"})
            append_event(root, {"type": "run_stopped", "reason": "done"})
            with self.assertRaisesRegex(WorkflowStateError, "already stopped"):
                append_event(root, {"type": "run_stopped", "reason": "late"})

    def test_loop_checkpoint_order_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-order"})
            append_event(root, {"type": "candidate_selected", "candidate": "one"})
            append_event(root, {"type": "budget_rechecked", "candidate": "one", "evidence": {"budget_path": "budget.json", "budget_hash": "a" * 64, "health_path": "health.json", "health_hash": "b" * 64}})
            append_event(root, {"type": "mutation_applied", "candidate": "one"})
            with self.assertRaisesRegex(WorkflowStateError, "immediately follow"):
                append_event(root, {"type": "continuation_granted", "candidate": "one"})

    def test_second_candidate_is_fail_closed_until_all_gates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-2"})
            append_event(root, {"type": "candidate_selected", "candidate": "one"})
            with self.assertRaisesRegex(WorkflowStateError, "second candidate"):
                append_event(root, {"type": "candidate_selected", "candidate": "two"})

    def test_same_candidate_cannot_be_reselected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-repeat"})
            append_event(root, {"type": "candidate_selected", "candidate": "one"})
            with self.assertRaisesRegex(WorkflowStateError, "already selected"):
                append_event(root, {"type": "candidate_selected", "candidate": "one"})

    def test_earlier_candidate_cannot_be_reselected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-cycle"})
            append_event(root, {"type": "candidate_selected", "candidate": "one"})
            append_event(root, {"type": "candidate_accepted", "candidate": "one"})
            append_event(root, {"type": "verifier_passed", "candidate": "one"})
            append_event(root, {"type": "budget_rechecked", "candidate": "one", "evidence": {"budget_path": "budget.json", "budget_hash": "a" * 64, "health_path": "health.json", "health_hash": "b" * 64}})
            append_event(root, {"type": "continuation_granted", "candidate": "one"})
            append_event(root, {"type": "candidate_selected", "candidate": "two"})
            with self.assertRaisesRegex(WorkflowStateError, "already selected"):
                append_event(root, {"type": "candidate_selected", "candidate": "one"})

    def test_tampering_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            append_event(root, {"type": "run_started", "run_id": "trial-3"})
            path = root / "events.jsonl"
            data = json.loads(path.read_text())
            data["run_id"] = "forged"
            path.write_text(json.dumps(data) + "\n")
            with self.assertRaisesRegex(WorkflowStateError, "hash"):
                replay_events(path)

    def test_unsupported_and_malformed_events_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(WorkflowStateError):
                append_event(root, {"type": "unknown"})
            (root / "events.jsonl").write_text("{}\n")
            with self.assertRaises(WorkflowStateError):
                replay_events(root / "events.jsonl")


if __name__ == "__main__":
    unittest.main()
