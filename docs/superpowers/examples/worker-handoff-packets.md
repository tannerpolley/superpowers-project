# Worker Handoff And PR-Ready Packets

These packets define the minimum evidence shape for orchestrated issue work. The orchestrator sends the worker handoff packet before worker execution. The worker returns the PR-ready packet after verification, branch push, and PR creation. Workers do not merge or close issues directly.

## Worker Handoff Packet

```json
{
  "packet_type": "worker_handoff",
  "issue_mirror": "docs/superpowers/issues/<issue-number>-<issue-slug>.md",
  "source_plan": "docs/superpowers/plans/<source-plan>.md",
  "goal_command": "/goal Resolve the delegated issue with complete worker handoff and PR-ready proof.",
  "branch": "codex/issue-<issue-number>-<issue-slug>",
  "branch_worktree_policy": "workspace provider is selected before worker creation",
  "workspace_provider": "codex_managed_worktree",
  "workspace_receipt": {
    "schema_version": 1,
    "provider": "codex_managed_worktree",
    "workspace_id": "<redacted-workspace>",
    "repository_root": "<ephemeral-canonical-root>",
    "git_common_dir": "<ephemeral-git-common-dir>",
    "run_id": "<run-id>",
    "candidate_id": "<candidate-id>",
    "task_id": "<redacted-task>",
    "thread_id": "<redacted-thread>",
    "observed_head": "<40-character-commit>",
    "head_mode": "branch",
    "branch": "codex/issue-<issue-number>-<issue-slug>",
    "owner": "codex_app",
    "disposition": "active"
  },
  "workspace_receipt_ref": "sha256:<redacted-receipt-hash>",
  "workflow_binding": {
    "run_id": "<run-id>",
    "candidate_id": "<candidate-id>"
  },
  "reviewer_role": "main-thread-orchestrator",
  "proof_oracle": [
    "./scripts/validate-worker-packets.sh"
  ],
  "validation": {
    "required_commands": [
      "./skills/orchestrate-issues/scripts/validate-worker-handoff.sh -RepoRoot . -HandoffPath <handoff-json>"
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
  "issue_mirror": "docs/superpowers/issues/<issue-number>-<issue-slug>.md",
  "source_plan": "docs/superpowers/plans/<source-plan>.md",
  "branch": "codex/issue-<issue-number>-<issue-slug>",
  "proof_oracle": [
    "./scripts/validate-worker-packets.sh",
    "./scripts/validate.sh"
  ],
  "diff_scope": {
    "changed_files": [
      "docs/superpowers/examples/worker-handoff-packets.md",
      "skills/orchestrate-issues/SKILL.md",
      "skills/orchestrate-issues/scripts/validate-worker-handoff.sh"
    ]
  },
  "validation_receipt": {
    "commands": [
      {
        "command": "./scripts/validate-worker-packets.sh",
        "exit_code": 0
      }
    ]
  },
  "merge_handoff": {
    "route": "merge-changes",
    "pr_url": "https://github.com/tannerpolley/superpowers-project/pull/<number>",
    "closes_issue": "https://github.com/<owner>/<repo>/issues/<issue-number>",
    "worker_must_not_merge": true
  }
}
```
