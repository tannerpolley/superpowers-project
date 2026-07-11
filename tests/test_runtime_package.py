from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.lib.package_provenance import load_runtime_package, runtime_contract_hash, runtime_manifest, validate_runtime_reads


ROOT = Path(__file__).resolve().parents[1]


class RuntimePackageTests(unittest.TestCase):
    def test_source_manifest_excludes_history_and_includes_runtime_contracts(self):
        package = load_runtime_package(ROOT)
        paths = {entry.path for entry in runtime_manifest(ROOT)}
        self.assertIn("docs/superpowers/workflow-contract.yml", paths)
        self.assertIn("docs/superpowers/capabilities.yml", paths)
        # The manifest already includes scripts/**, so kernel modules need no per-file manifest edits.
        self.assertIn("scripts/lib/evidence_schema.py", paths)
        self.assertIn("scripts/lib/evidence_collectors.py", paths)
        self.assertIn("scripts/lib/commands/gates.py", paths)
        self.assertIn("docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md", paths)
        self.assertIn("docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md", paths)
        self.assertEqual([], validate_runtime_reads(ROOT, package))

    def test_included_content_and_mode_change_hash_but_excluded_history_does_not(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "repo"
            shutil.copytree(ROOT, target)
            first = runtime_contract_hash(target)
            history = target / "docs" / "superpowers" / "milestones" / "history.md"
            history.write_text("one")
            self.assertEqual(first, runtime_contract_hash(target))
            script = target / "scripts" / "workflow-run.sh"
            script.write_text(script.read_text() + "\n# changed\n")
            self.assertNotEqual(first, runtime_contract_hash(target))
            second = runtime_contract_hash(target)
            script.chmod(0o644)
            self.assertNotEqual(second, runtime_contract_hash(target))

    def test_missing_runtime_read_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "repo"
            shutil.copytree(ROOT, target)
            manifest = target / ".codex-plugin" / "runtime-package.yml"
            manifest.write_text(manifest.read_text().replace("  - docs/superpowers/capabilities.yml\n", ""))
            findings = validate_runtime_reads(target, load_runtime_package(target))
            self.assertTrue(any("capabilities.yml" in finding for finding in findings))


if __name__ == "__main__":
    unittest.main()
