from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.lib.package_provenance import (
    load_runtime_package,
    runtime_contract_hash,
    runtime_manifest,
    validate_runtime_reads,
    verify_runtime_provenance,
)


ROOT = Path(__file__).resolve().parents[1]


class RuntimePackageTests(unittest.TestCase):
    def write_manifest(self, root: Path) -> None:
        plugin = root / ".codex-plugin"
        plugin.mkdir(exist_ok=True)
        (plugin / "runtime-package.yml").write_text(
            "version: 1\ninclude:\n  - .codex-plugin/**\n  - scripts/**\n  - skills/**\n  - docs/superpowers/**\n"
        )

    def test_source_manifest_includes_runtime_contracts_and_excludes_history(self):
        package = load_runtime_package(ROOT)
        paths = {entry.path for entry in runtime_manifest(ROOT)}
        required = {
            "docs/superpowers/workflow-contract.yml",
            "docs/superpowers/capabilities.yml",
            "scripts/lib/evidence_schema.py",
            "scripts/lib/evidence_collectors.py",
            "scripts/lib/commands/gates.py",
        }
        self.assertLessEqual(required, paths)
        self.assertEqual(
            {
                "docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md",
                "docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md",
            },
            {path for path in paths if path.startswith(("docs/superpowers/specs/", "docs/superpowers/plans/"))},
        )
        self.assertEqual([], validate_runtime_reads(ROOT, package))

    def test_hash_tracks_included_content_and_executable_mode_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "repo"
            shutil.copytree(ROOT, target)
            first = runtime_contract_hash(target)
            (target / "docs/superpowers/specs/completed-history.md").write_text("excluded\n")
            self.assertEqual(first, runtime_contract_hash(target))
            script = target / "scripts/workflow-run.sh"
            script.write_text(script.read_text() + "\n# changed\n")
            changed = runtime_contract_hash(target)
            self.assertNotEqual(first, changed)
            script.chmod(0o775)
            self.assertEqual(changed, runtime_contract_hash(target))
            script.chmod(0o644)
            self.assertNotEqual(changed, runtime_contract_hash(target))

    def test_hash_is_location_independent_and_provenance_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "one"
            root.mkdir()
            self.write_manifest(root)
            (root / ".codex-plugin/plugin.json").write_text("{}")
            (root / "scripts").mkdir()
            (root / "scripts/run.sh").write_text("echo one\n")
            sibling = Path(tmp) / "two"
            shutil.copytree(root, sibling)
            self.assertEqual(runtime_contract_hash(root), runtime_contract_hash(sibling))

            project = root / "project"
            project.mkdir()
            ledger = {
                "manifest": [entry.to_dict() for entry in runtime_manifest(root)],
                "contract_hash": runtime_contract_hash(root),
                "project_root": str(project),
            }
            verify_runtime_provenance(ledger, root, project)
            ledger["contract_hash"] = "0" * 64
            with self.assertRaises(ValueError):
                verify_runtime_provenance(ledger, root, project)

    def test_missing_runtime_read_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "repo"
            shutil.copytree(ROOT, target)
            manifest = target / ".codex-plugin/runtime-package.yml"
            manifest.write_text(manifest.read_text().replace("  - docs/superpowers/capabilities.yml\n", ""))
            self.assertTrue(any("capabilities.yml" in finding for finding in validate_runtime_reads(target, load_runtime_package(target))))


if __name__ == "__main__":
    unittest.main()
