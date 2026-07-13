import json
import subprocess
import sys
import tempfile
import unittest
from shutil import copytree
from pathlib import Path

from scripts.lib.command_catalog import CommandSpec, ScriptError, _COMMANDS, build_command_registry, load_command_catalog, resolve_command
from scripts.lib.commands import load_handlers


ROOT = Path(__file__).resolve().parents[1]


class CommandRegistryTests(unittest.TestCase):
    def test_workspace_policy_launcher_is_registered_as_mutation_free(self):
        self.assertEqual("command_workspace_isolation", _COMMANDS["scripts/workspace-isolation.sh"])
        self.assertEqual("none", load_command_catalog(ROOT)["scripts/workspace-isolation.sh"].mutation)

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
        catalog = load_command_catalog(ROOT)
        launchers = {p.relative_to(ROOT).as_posix() for base in (ROOT / "scripts", ROOT / "skills") for p in base.rglob("*.sh") if "/lib/" not in p.as_posix()}
        self.assertEqual(launchers, set(registry))
        for path, spec in catalog.items():
            with self.subTest(path=path):
                process = subprocess.run(
                    ["bash", str(ROOT / path), "-DispatchProbe"],
                    cwd="/tmp",
                    text=True,
                    capture_output=True,
                )
                self.assertEqual(0, process.returncode, process.stdout + process.stderr)
                self.assertEqual(
                    {"ok": True, "path": path, "handler": spec.handler, "kind": spec.kind, "mutation": spec.mutation},
                    json.loads(process.stdout),
                )

    def test_library_file_is_not_classified_as_test(self):
        registry = build_command_registry(ROOT)
        self.assertNotIn("scripts/lib/superpowers_project_cli.py", registry)

    def test_unknown_path_fails_closed(self):
        with self.assertRaisesRegex(Exception, "unregistered script path"):
            resolve_command("scripts/test-unknown.sh", ROOT)

    def test_registry_has_no_generic_failure_handlers(self):
        incomplete = {
            path: handler
            for path, handler in _COMMANDS.items()
            if handler.endswith("_unimplemented")
        }
        self.assertEqual({}, incomplete)

    def test_every_registered_handler_is_callable(self):
        sys.path.insert(0, str(ROOT / "scripts" / "lib"))
        try:
            import superpowers_project_cli as cli
        finally:
            sys.path.pop(0)
        missing = sorted(
            {handler for handler in _COMMANDS.values() if not callable(cli.resolve_handler(handler))}
        )
        self.assertEqual([], missing)
        expected_modules = {
            "command_workflow_run": "commands.workflow",
            "command_validate_agent_usability_receipt": "commands.validation",
            "command_select_candidate": "commands.project",
            "command_prepare_release": "commands.distribution",
        }
        handlers = load_handlers()
        for name, module in expected_modules.items():
            self.assertTrue(handlers[name].__module__.endswith(module))

    def test_execution_kernel_collection_handlers_are_registered(self):
        handlers = load_handlers()
        self.assertEqual(
            {"command_collect_pr_ready", "command_collect_premerge", "command_collect_closeout"},
            {name for name in handlers if name.startswith("command_collect_") and name in {"command_collect_pr_ready", "command_collect_premerge", "command_collect_closeout"}},
        )

    def test_typed_catalog_has_known_kinds_and_mutation_classes(self):
        catalog = load_command_catalog(ROOT)
        self.assertTrue(catalog)
        self.assertTrue(all(isinstance(spec, CommandSpec) for spec in catalog.values()))
        self.assertTrue(all(spec.kind in {"validator", "test", "workflow", "distribution", "project"} for spec in catalog.values()))
        self.assertTrue(all(spec.mutation in {"none", "project", "git", "deployment", "external"} for spec in catalog.values()))
        self.assertEqual(set(catalog), {spec.path for spec in catalog.values()})

    def test_public_validator_runs_from_arbitrary_cwd(self):
        script = ROOT / "scripts/validate-workflow-contract.sh"
        process = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(ROOT)],
            cwd="/tmp",
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, process.returncode, process.stdout + process.stderr)
        payload = __import__("json").loads(process.stdout)
        self.assertTrue(payload["ok"])
        self.assertEqual("workflow-contract", payload["phase"])

    def test_evidence_launchers_fail_closed_without_a_request(self):
        paths = (
            "skills/resolve-issue/scripts/validate-pr-ready.sh",
            "skills/merge-changes/scripts/premerge.sh",
            "skills/merge-changes/scripts/validate-merge-decision.sh",
            "skills/merge-changes/scripts/closeout.sh",
            "skills/resolve-issue/scripts/collect-pr-ready-ledger.sh",
            "skills/merge-changes/scripts/collect-premerge-ledger.sh",
            "skills/merge-changes/scripts/collect-closeout-ledger.sh",
        )
        for path in paths:
            with self.subTest(path=path):
                process = subprocess.run(["bash", str(ROOT / path)], cwd=ROOT, text=True, capture_output=True)
                self.assertNotEqual(0, process.returncode)
                self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])
