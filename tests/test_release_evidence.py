import tempfile
import unittest
from pathlib import Path

from scripts.lib.release_evidence import ReleaseEvidenceError, base_release_tag, validate_dependency_pins, validate_release_evidence


ROOT = Path(__file__).resolve().parents[1]


class ReleaseEvidenceTests(unittest.TestCase):
    def test_validation_dependencies_are_exactly_pinned(self):
        self.assertEqual([], validate_dependency_pins(ROOT / "requirements-validation.txt"))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "requirements.txt"
            path.write_text("PyYAML>=6\n")
            self.assertTrue(validate_dependency_pins(path))

    def test_base_tag_never_contains_build_metadata(self):
        self.assertEqual("v0.3.0", base_release_tag("0.3.0+codex.local"))
        with self.assertRaises(ReleaseEvidenceError):
            base_release_tag("0.3")

    def test_release_evidence_rejects_stale_agent_and_missing_install_proof(self):
        evidence = {
            "commit": "abc",
            "package_hash": "hash",
            "manifest_version": "0.3.0",
            "validation": {"ok": True, "commit": "abc", "package_hash": "hash"},
            "sync": {"ok": True, "commit": "abc", "package_hash": "hash"},
            "installation": {"ok": True, "commit": "abc", "package_hash": "hash", "manifest_version": "0.3.0"},
            "cleanup": {"ok": True, "commit": "abc", "package_hash": "hash"},
            "agent_trials": {"ok": True, "package_hash": "hash"},
        }
        validate_release_evidence(evidence)
        stale = {**evidence, "agent_trials": {"ok": True, "package_hash": "old"}}
        with self.assertRaises(ReleaseEvidenceError):
            validate_release_evidence(stale)
        missing = {**evidence, "installation": {}}
        with self.assertRaises(ReleaseEvidenceError):
            validate_release_evidence(missing)

    def test_release_identity_is_aligned(self):
        import json
        manifest = json.loads((ROOT / ".codex-plugin" / "plugin.json").read_text())
        self.assertEqual("0.3.0", manifest["version"])
        self.assertIn("## 0.3.0 - 2026-07-09", (ROOT / "CHANGELOG.md").read_text())
        policy = (ROOT / "docs" / "superpowers" / "RELEASE_POLICY.md").read_text()
        self.assertIn("`v0.3.0`", policy)
        self.assertIn("Do not push the tag", policy)


if __name__ == "__main__":
    unittest.main()
