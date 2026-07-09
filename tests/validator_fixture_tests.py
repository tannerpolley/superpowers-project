import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parents[1]))
from scripts.lib.validator_fixture_tests import main

class ValidatorFixtureTests(unittest.TestCase):
    def test_plan_task(self): self.assertEqual(main('task'), 0)
    def test_plan_outcome(self): self.assertEqual(main('outcome'), 0)
    def test_decision(self): self.assertEqual(main('decision'), 0)
    def test_workflow(self): self.assertEqual(main('workflow'), 0)

if __name__ == '__main__': unittest.main()
