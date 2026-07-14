import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.lib.skill_slimming import load_capabilities, validate_route_capabilities, validate_skill_slimming


ROOT = Path(__file__).resolve().parents[1]


class SkillSlimmingTests(unittest.TestCase):
    def test_execution_routes_defer_to_repository_verification_policy(self):
        capabilities = (ROOT / "docs" / "superpowers" / "capabilities.yml").read_text(encoding="utf-8")
        self.assertNotIn("superpowers:test-driven-development", capabilities)

        for route in ["write-plan", "implement-plan", "resolve-issue", "orchestrate-issues"]:
            text = (ROOT / "skills" / route / "SKILL.md").read_text(encoding="utf-8").lower()
            self.assertIn("repository verification policy", text, route)
        self.assertNotIn("red/green/refactor steps", (ROOT / "skills" / "write-plan" / "SKILL.md").read_text(encoding="utf-8").lower())

    def test_skill_text_is_compact_and_current(self):
        skill_files = sorted((ROOT / "skills").glob("*/SKILL.md"))
        words = {path.parent.name: len(path.read_text(encoding="utf-8").split()) for path in skill_files}
        self.assertLessEqual(words["advanced-user-input"], 1400)
        self.assertLessEqual(max(count for name, count in words.items() if name != "advanced-user-input"), 400)
        self.assertLessEqual(sum(words.values()), 4500)

        text = (ROOT / "skills" / "advanced-user-input" / "SKILL.md").read_text(encoding="utf-8")
        self.assertNotIn("Final clean closeout gates may use Yes, Revisit, and Done", text)
        self.assertIn("Verified final health gates use exactly three top-level options: Done, Revisit, and Stop", text)

        for path in skill_files:
            if path.parent.name == "advanced-user-input":
                continue
            text = path.read_text(encoding="utf-8")
            self.assertIn("skills/advanced-user-input/SKILL.md", text, path)
            self.assertNotIn("Keep route-specific", text, path)

        metadata_files = sorted((ROOT / "skills").glob("*/agents/openai.yaml"))
        metadata_words = {path.parents[1].name: len(path.read_text(encoding="utf-8").split()) for path in metadata_files}
        self.assertLessEqual(max(metadata_words.values()), 120)
        self.assertLessEqual(sum(metadata_words.values()), 1100)
        self.assertNotIn("live plugin sync drift, live plugin sync drift", "\n".join(path.read_text(encoding="utf-8") for path in metadata_files))

    def test_route_skills_declare_capabilities_and_meet_size_target(self):
        contract = load_capabilities(ROOT / "docs" / "superpowers" / "capabilities.yml")
        findings, metrics = validate_skill_slimming(ROOT, contract)
        self.assertEqual([], findings)
        self.assertLessEqual(metrics["route_lines"], metrics["target_route_lines"])
        self.assertGreaterEqual(metrics["reduction_percent"], 30.0)

    def test_missing_available_capability_fails_before_execution(self):
        contract = load_capabilities(ROOT / "docs" / "superpowers" / "capabilities.yml")
        required = contract["routes"]["resolve-issue"]["required"]
        with self.assertRaisesRegex(ValueError, required[0]):
            validate_route_capabilities("resolve-issue", required[1:], contract)

    def test_missing_declaration_and_duplicated_policy_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "repo"
            __import__("shutil").copytree(ROOT, target)
            metadata = target / "skills" / "write-plan" / "agents" / "openai.yaml"
            data = yaml.safe_load(metadata.read_text())
            data["interface"].pop("capabilities", None)
            metadata.write_text(yaml.safe_dump(data, sort_keys=False))
            skill = target / "skills" / "write-plan" / "SKILL.md"
            skill.write_text(skill.read_text() + "\nThe agent must not get out of the loop by itself\n")
            contract = load_capabilities(target / "docs" / "superpowers" / "capabilities.yml")
            findings, _ = validate_skill_slimming(target, contract)
            codes = {finding["code"] for finding in findings}
            self.assertIn("missing-capability-declaration", codes)
            self.assertIn("duplicated-global-policy", codes)


if __name__ == "__main__":
    unittest.main()
