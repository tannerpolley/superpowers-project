import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/test-advanced-user-input-policy.sh"


class AdvancedUserInputPolicyTests(unittest.TestCase):
    def test_policy_launcher_returns_structured_success(self):
        result = subprocess.run(["bash", str(SCRIPT)], cwd="/tmp", text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["phase"], "advanced-user-input-policy")

if __name__ == "__main__":
    unittest.main()
