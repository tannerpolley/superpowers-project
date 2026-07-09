import unittest
from pathlib import Path

from scripts.lib.workflow_graph import load_workflow_graph, render_outcome_workflow, render_route_index


ROOT = Path(__file__).resolve().parents[1]


class WorkflowGenerationTests(unittest.TestCase):
    def test_generated_review_surfaces_are_current(self):
        graph = load_workflow_graph(ROOT / "docs" / "superpowers" / "workflow-contract.yml")
        self.assertEqual(render_outcome_workflow(graph), (ROOT / "docs" / "superpowers" / "OUTCOME_WORKFLOW.md").read_text())
        self.assertEqual(render_route_index(graph), (ROOT / "docs" / "superpowers" / "WORKFLOW_ROUTE_INDEX.md").read_text())


if __name__ == "__main__":
    unittest.main()
