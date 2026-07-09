import copy
import tempfile
import unittest
from pathlib import Path

import yaml

from scripts.lib.skill_slimming import load_capabilities, validate_route_capabilities, validate_skill_slimming


ROOT = Path(__file__).resolve().parents[1]


class SkillSlimmingTests(unittest.TestCase):
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
