import tempfile
import unittest
from unittest.mock import patch
import sys
from pathlib import Path

from scripts.lib.superpowers_project_context import (
    RuntimeContext,
    resolve_plugin_path,
    resolve_project_path,
    resolve_project_root,
)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts/lib"))
from superpowers_project_cli import Context, project_root_for


class RuntimeContextTests(unittest.TestCase):
    def test_nested_validation_does_not_inherit_read_only_collection_marker(self):
        from scripts.lib.superpowers_project_cli import run_without_read_only_collection
        with patch.dict("os.environ", {"SUPERPOWERS_READ_ONLY_COLLECTION": "1"}):
            result = run_without_read_only_collection(["bash", "-c", "test -z \"${SUPERPOWERS_READ_ONLY_COLLECTION:-}\""], Path(__file__).resolve().parents[1])
        self.assertEqual(0, result.returncode)

    def test_external_project_root_is_allowed(self):
        with tempfile.TemporaryDirectory() as d:
            project = Path(d).resolve()
            ctx = RuntimeContext(Path(__file__), project.parent, project.parent, "tests/x")
            self.assertEqual(resolve_project_root(ctx, {"RepoRoot": str(project)}), project)

    def test_project_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve()
            with self.assertRaisesRegex(Exception, "outside project root"):
                resolve_project_path(root, "../outside", "Path")

    def test_plugin_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve()
            with self.assertRaisesRegex(Exception, "outside plugin root"):
                resolve_plugin_path(root, "../outside", "Path")

    def test_project_root_adapter_resolves_relative_to_invocation_cwd(self):
        with tempfile.TemporaryDirectory() as d:
            cwd = Path(d).resolve()
            ctx = Context(Path(__file__), cwd, "tests/x", "x", [], plugin_root=cwd, invocation_cwd=cwd)
            self.assertEqual(project_root_for(ctx, {"RepoRoot": "."}), cwd)
