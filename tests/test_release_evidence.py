import tempfile
import unittest
from pathlib import Path

from scripts.lib.release_evidence import ReleaseEvidenceError, base_release_tag, validate_dependency_pins


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

if __name__ == "__main__":
    unittest.main()
