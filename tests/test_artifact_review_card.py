import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
VALIDATOR = ROOT / "scripts" / "validate-artifact-review-card.sh"


def card() -> dict:
    return {
        "Gate": "continuation",
        "Created/changed": [{"path": "docs/superpowers/specs/example.md", "action": "created"}],
        "Proof": [{"evidence": "python3 -m unittest", "ok": True}],
        "Decisions": [{"decision": "continue to planning", "impact": "preserves governed route"}],
        "Risks": [{"risk": "fixture only", "owner": "release maintainer"}],
        "Recommended next route": "write-plan",
    }


class ArtifactReviewCardTests(unittest.TestCase):
    def run_validator(self, payload: dict) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = Path(tmp) / "card.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return subprocess.run(
                ["bash", str(VALIDATOR), "-Path", str(path)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

    def test_accepts_complete_card(self):
        result = self.run_validator(card())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('"ok": true', result.stdout)

    def test_rejects_unowned_risk(self):
        payload = card()
        payload["Risks"] = [{"risk": "unowned"}]
        result = self.run_validator(payload)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires risk and owner", result.stdout)


if __name__ == "__main__":
    unittest.main()
