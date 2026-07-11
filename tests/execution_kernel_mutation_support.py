from __future__ import annotations

from contextlib import contextmanager
from dataclasses import replace
from unittest.mock import patch

from scripts.lib.gate_common import finalize_gate_rules as real_finalize


@contextmanager
def mutate_gate_rule(module, gate: str, rule_id: str, mutation: str):
    """Test-only injection seam that mutates rules immediately before production finalization."""
    def injected(actual_gate, rules):
        if actual_gate != gate:
            return real_finalize(actual_gate, rules)
        if mutation == "remove":
            mutated = [rule for rule in rules if rule.rule_id != rule_id]
        elif mutation == "invert":
            mutated = [replace(rule, ok=False, reason="mutant inverted required rule") if rule.rule_id == rule_id else rule for rule in rules]
        else:
            raise AssertionError(f"unsupported mutation: {mutation}")
        return real_finalize(actual_gate, mutated)

    with patch.object(module, "finalize_gate_rules", side_effect=injected):
        yield
