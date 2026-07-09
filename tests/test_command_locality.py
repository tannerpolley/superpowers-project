import unittest

from scripts.lib.commands import load_handlers


class CommandLocalityTests(unittest.TestCase):
    def test_deep_handlers_live_in_focused_modules(self):
        handlers = load_handlers()
        expected = {
            "command_workflow_run": "commands.workflow",
            "command_validate_agent_usability_receipt": "commands.validation",
            "command_select_candidate": "commands.project",
            "command_prepare_release": "commands.distribution",
        }
        for name, suffix in expected.items():
            with self.subTest(name=name):
                self.assertIn(name, handlers)
                self.assertTrue(handlers[name].__module__.endswith(suffix), handlers[name].__module__)


if __name__ == "__main__":
    unittest.main()
