import subprocess
import sys
import tempfile
import unittest
from shutil import copytree
from pathlib import Path

from scripts.lib.superpowers_project_command_registry import ScriptError, _COMMANDS, build_command_registry, resolve_command


ROOT = Path(__file__).resolve().parents[1]


class CommandRegistryTests(unittest.TestCase):
    def test_known_skill_launcher_is_explicitly_configured(self):
        self.assertIn("skills/loop-controller/scripts/validate-budget.sh", _COMMANDS)

    def test_registry_drift_reports_extra_launcher(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            copytree(ROOT / "scripts", root / "scripts")
            copytree(ROOT / "skills", root / "skills")
            extra = root / "scripts" / "extra-launcher.sh"
            extra.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
            with self.assertRaisesRegex(ScriptError, "extra-launcher.sh"):
                build_command_registry(root)

    def test_every_shipped_launcher_has_one_entry(self):
        registry = build_command_registry(ROOT)
        launchers = {p.relative_to(ROOT).as_posix() for base in (ROOT / "scripts", ROOT / "skills") for p in base.rglob("*.sh") if "/lib/" not in p.as_posix()}
        self.assertEqual(launchers, set(registry))

    def test_library_file_is_not_classified_as_test(self):
        registry = build_command_registry(ROOT)
        self.assertNotIn("scripts/lib/superpowers_project_cli.py", registry)

    def test_unknown_path_fails_closed(self):
        with self.assertRaisesRegex(Exception, "unregistered script path"):
            resolve_command("scripts/test-unknown.sh")

    def test_unimplemented_launcher_from_arbitrary_cwd(self):
        script = ROOT / "scripts/detect-stale-skill-contract.sh"
        p = subprocess.run(["bash", str(script)], cwd="/tmp", text=True, capture_output=True)
        self.assertNotEqual(p.returncode, 0)
        payload = __import__('json').loads(p.stdout)
        self.assertFalse(payload["ok"])
        self.assertIn("command not implemented", payload["reason"])
