import json
import os
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parents[1] / "scripts" / "lib"))
from package_provenance import runtime_contract_hash, runtime_manifest, verify_runtime_provenance


class PackageProvenanceTests(unittest.TestCase):
    def test_hash_covers_content_and_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            p = root / "scripts" / "run.sh"
            p.write_text("echo one\n")
            first = runtime_contract_hash(root)
            p.write_text("echo two\n")
            self.assertNotEqual(first, runtime_contract_hash(root))
            p.chmod(0o755)
            self.assertNotEqual(first, runtime_contract_hash(root))

    def test_contract_and_skill_changes_are_hashed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / "docs/superpowers").mkdir(parents=True); (root / "skills/demo").mkdir(parents=True)
            contract = root / "docs/superpowers/workflow-contract.yml"; skill = root / "skills/demo/SKILL.md"
            contract.write_text("state: one"); skill.write_text("name: demo\n")
            first = runtime_contract_hash(root)
            contract.write_text("state: two"); self.assertNotEqual(first, runtime_contract_hash(root))
            second = runtime_contract_hash(root); skill.write_text("name: changed\n"); self.assertNotEqual(second, runtime_contract_hash(root))

    def test_forged_ledger_and_wrong_project_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".codex-plugin").mkdir()
            (root / ".codex-plugin" / "plugin.json").write_text("{}")
            project = root / "project"
            project.mkdir()
            entries = [e.to_dict() for e in runtime_manifest(root)]
            ledger = {"manifest": entries, "contract_hash": runtime_contract_hash(root), "project_root": str(project)}
            verify_runtime_provenance(ledger, root, project)
            ledger["contract_hash"] = "0" * 64
            with self.assertRaises(ValueError):
                verify_runtime_provenance(ledger, root, project)

    def test_sibling_copy_has_same_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "one"
            root.mkdir()
            (root / "scripts").mkdir()
            (root / "scripts" / "x").write_text("x")
            copy = Path(tmp) / "two"
            import shutil
            shutil.copytree(root, copy)
            self.assertEqual(runtime_contract_hash(root), runtime_contract_hash(copy))


if __name__ == "__main__":
    unittest.main()
