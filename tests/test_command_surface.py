import json
import subprocess
import unittest
from pathlib import Path

from scripts.lib.command_catalog import load_command_catalog


ROOT = Path(__file__).resolve().parents[1]


class CommandSurfaceTests(unittest.TestCase):
    def test_every_launcher_reports_its_exact_dispatch_spec(self):
        for path, spec in load_command_catalog(ROOT).items():
            with self.subTest(path=path):
                process = subprocess.run(
                    ["bash", str(ROOT / path), "-DispatchProbe"],
                    cwd="/tmp",
                    text=True,
                    capture_output=True,
                )
                self.assertEqual(0, process.returncode, process.stdout + process.stderr)
                payload = json.loads(process.stdout)
                self.assertEqual(
                    {
                        "ok": True,
                        "path": path,
                        "handler": spec.handler,
                        "kind": spec.kind,
                        "mutation": spec.mutation,
                    },
                    payload,
                )


if __name__ == "__main__":
    unittest.main()
