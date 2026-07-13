from __future__ import annotations

import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]


class UpstreamVisualCompanionTests(unittest.TestCase):
    def test_brainstorm_route_delegates_visual_questions_to_superpowers(self):
        skill = (ROOT / "skills/brainstorm-spec/SKILL.md").read_text(encoding="utf-8")

        self.assertIn("superpowers:brainstorming", skill)
        self.assertIn("just-in-time visual companion", skill)
        self.assertIn("browser events are advisory", skill)
        self.assertNotIn("$superpowers-project:companion-interface", skill)

    def test_agent_native_companion_surface_is_removed(self):
        retired_paths = (
            "skills/companion-interface",
            "scripts/test-agent-native-companion-preview.sh",
            "scripts/test-companion-interface.sh",
            "scripts/docker-agent-native-preview.mjs",
            "docker/agent-native-preview.Dockerfile",
            "docker-compose.agent-native-preview.yml",
            "plans/agent-native-companion-replacement",
        )
        self.assertEqual([], [path for path in retired_paths if (ROOT / path).exists()])

        active_surfaces = (
            ".codex-plugin/plugin.json",
            "README.md",
            "docs/superpowers/PROJECT_CONTEXT.md",
            "docs/superpowers/capabilities.yml",
            "skills/brainstorm-spec/SKILL.md",
            "skills/brainstorm-spec/agents/openai.yaml",
            "skills/write-plan/agents/openai.yaml",
            "scripts/lib/command_catalog.py",
            "scripts/lib/superpowers_project_cli.py",
        )
        for path in active_surfaces:
            with self.subTest(path=path):
                text = (ROOT / path).read_text(encoding="utf-8")
                self.assertNotIn("Agent-Native", text)
                self.assertNotIn("companion-interface", text)

    def test_workflow_graph_has_no_duplicate_companion_route_or_gate(self):
        contract = yaml.safe_load((ROOT / "docs/superpowers/workflow-contract.yml").read_text(encoding="utf-8"))
        routes = contract["workflow_skills"]

        self.assertNotIn("companion-interface", routes)
        question_ids = {
            gate["question_id"]
            for route in routes.values()
            for gate in route.get("gates", [])
        }
        self.assertNotIn("project_brainstorm_visual_companion", question_ids)
        self.assertEqual(["write-plan"], routes["brainstorm-spec"]["next_routes"])


if __name__ == "__main__":
    unittest.main()
