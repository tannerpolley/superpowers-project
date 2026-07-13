from __future__ import annotations

import copy
import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.lib.workflow_graph import load_workflow_graph, render_outcome_workflow, render_route_index, validate_workflow_graph


ROOT = Path(__file__).resolve().parents[1]
VALID = ROOT / "tests" / "fixtures" / "workflow_graph" / "valid.yml"


class WorkflowGraphTests(unittest.TestCase):
    def findings(self, mutate):
        data = yaml.safe_load(VALID.read_text())
        mutate(data)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "graph.yml"
            path.write_text(yaml.safe_dump(data, sort_keys=False))
            graph = load_workflow_graph(path)
            return [finding.code for finding in validate_workflow_graph(graph, ROOT)]

    def test_nine_malformed_graph_classes_fail_exactly(self):
        cases = {
            "boolean-label": lambda d: d["workflow_skills"]["alpha"]["gates"][0]["options"].__setitem__(0, True),
            "duplicate-question-id": lambda d: d["workflow_skills"]["beta"]["gates"][0].__setitem__("question_id", "alpha_next"),
            "wrong-parent": lambda d: d["workflow_skills"]["alpha"]["gates"][0].__setitem__("parent_option", "Missing"),
            "illegal-terminal": lambda d: d["workflow_skills"]["beta"]["gates"][0]["options"][0].__setitem__("label", "Yes"),
            "missing-owner": lambda d: d["workflow_skills"]["alpha"].pop("owner"),
            "missing-artifacts": lambda d: d["workflow_skills"]["alpha"].pop("artifacts"),
            "missing-validators": lambda d: d["workflow_skills"]["alpha"].pop("validators"),
            "unreachable-route": lambda d: d["workflow_skills"].__setitem__("orphan", copy.deepcopy(d["workflow_skills"]["beta"])),
            "missing-transitions": lambda d: d["workflow_skills"]["alpha"].pop("next_routes"),
        }
        for expected, mutation in cases.items():
            with self.subTest(expected=expected):
                self.assertIn(expected, self.findings(mutation))

    def test_canonical_graph_is_valid_and_generation_is_stable(self):
        graph = load_workflow_graph(ROOT / "docs" / "superpowers" / "workflow-contract.yml")
        self.assertEqual([], validate_workflow_graph(graph, ROOT))
        summaries = {render_outcome_workflow(graph) for _ in range(5)}
        indexes = {render_route_index(graph) for _ in range(5)}
        self.assertEqual(1, len(summaries))
        self.assertEqual(1, len(indexes))

    def test_generated_summary_names_auto_outcome_not_route(self):
        graph = load_workflow_graph(ROOT / "docs" / "superpowers" / "workflow-contract.yml")
        summary = render_outcome_workflow(graph)
        self.assertIn("`outcome`: the one authorized Auto outcome", summary)
        self.assertNotIn("one authorized Auto route", summary)


if __name__ == "__main__":
    unittest.main()
