from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.prove_installed_execution_kernel import prove_installed_execution_kernel


ROOT = Path(__file__).resolve().parents[1]


class InstalledExecutionKernelTests(unittest.TestCase):
    def test_installed_public_launcher_fails_missing_and_passes_valid_fixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            installed = Path(tmp) / "installed"
            shutil.copytree(ROOT, installed, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
            proof = prove_installed_execution_kernel(ROOT, installed)
            self.assertEqual("evidence_missing", proof["negative_error_code"])
            self.assertEqual("pr-ready-validator@1", proof["validator_id"])
            self.assertEqual(proof["source_package_hash"], proof["installed_package_hash"])
            self.assertTrue(str(proof["envelope_hash"]).startswith("sha256:"))
            self.assertTrue(str(proof["receipt_hash"]).startswith("sha256:"))


if __name__ == "__main__":
    unittest.main()
