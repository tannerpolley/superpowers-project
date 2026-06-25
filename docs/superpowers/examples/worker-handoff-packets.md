# Worker Handoff And PR-Ready Packets

These packets define the minimum evidence shape for orchestrated issue work. The orchestrator sends the worker handoff packet before worker execution. The worker returns the PR-ready packet after verification, branch push, and PR creation. Workers do not merge or close issues directly.

## Worker Handoff Packet

```json
{
  "packet_type": "worker_handoff",
  "issue_mirror": "docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md",
  "source_plan": "docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md",
  "goal_command": "/goal Add sample worker handoff and PR-ready packets with validation for orchestrated issue work.",
  "branch": "codex/issue-70-worker-handoff-pr-ready-packets",
  "branch_worktree_policy": "worker creates an isolated worktree for the branch",
  "reviewer_role": "main-thread-orchestrator",
  "proof_oracle": [
    "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\test-worker-packets.ps1",
    "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\skills\\orchestrate-issues\\scripts\\test-scenarios.ps1"
  ],
  "validation": {
    "required_commands": [
      "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\skills\\orchestrate-issues\\scripts\\validate-worker-handoff.ps1 -RepoRoot . -HandoffPath <handoff-json>"
    ]
  },
  "merge_handoff": {
    "merge_owner": "merge-changes",
    "worker_must_not_merge": true
  }
}
```

## PR-Ready Return Packet

```json
{
  "packet_type": "pr_ready",
  "issue_mirror": "docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md",
  "source_plan": "docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md",
  "branch": "codex/issue-70-worker-handoff-pr-ready-packets",
  "proof_oracle": [
    "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\test-worker-packets.ps1",
    "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\validate.ps1"
  ],
  "diff_scope": {
    "changed_files": [
      "docs/superpowers/examples/worker-handoff-packets.md",
      "skills/orchestrate-issues/SKILL.md",
      "skills/orchestrate-issues/scripts/validate-worker-handoff.ps1"
    ]
  },
  "validation_receipt": {
    "commands": [
      {
        "command": "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\test-worker-packets.ps1",
        "exit_code": 0
      },
      {
        "command": "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\\skills\\orchestrate-issues\\scripts\\test-scenarios.ps1",
        "exit_code": 0
      }
    ]
  },
  "merge_handoff": {
    "route": "merge-changes",
    "pr_url": "https://github.com/tannerpolley/superpowers-project/pull/<number>",
    "closes_issue": "https://github.com/tannerpolley/superpowers-project/issues/70",
    "worker_must_not_merge": true
  }
}
```
