# Score 9+ And Looping Mode Hardening Receipt

## Scope

- Source spec: `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`
- Source plan: `docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md`
- Milestone: `M1 - Source Of Truth`
- Linked issue slice: `https://github.com/tannerpolley/superpowers-project/issues/87`

## Scorecard

| Area | Target | Evidence | Result |
|---|---:|---|---|
| Full workflow coverage | >=9.3 | `docs/superpowers/workflow-contract.yml`, exact option validation, material gate registration | pass |
| Project context + issues | >=9.1 | `docs/superpowers/PROJECT_CONTEXT.md`, `docs/superpowers/backlog/ACTIVE.md`, issue mirrors, milestone receipt links | pass |
| Decision gates | >=9.2 | typed workflow gates, exact SKILL option checks, native approval and permission validators | pass |
| Grilling behavior | >=9.1 | Decision Ledger validation, source plan Decision Ledger, and issue-backed planning receipts | pass |
| Clear goals/outputs | >=9.2 | Outcome Proof, Implementation Boundaries, Artifact Review Card schema, and issue Outcome Summary receipts | pass |
| Predictability | >=9.1 | metadata geometry checks, workflow examples, Looping Mode state-machine proof, and generated-state guardrails | pass |
| Friction/clutter | >=9.0 | compact metadata validation and global policy deduplication checks | pass |
| Ship confidence | >=9.0 | repo validation, live sync validation, version freshness, tracker hygiene, cleanup hook, and clean Git proof | pass |

## Command Receipts

| Proof | Command | Result |
|---|---|---|
| workflow contract tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1` | pass |
| workflow contract validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .` | pass |
| metadata tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1` | pass |
| metadata validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-metadata-contract.ps1 -RepoRoot .` | pass |
| loop controller tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1` | pass |
| loop scenarios | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1` | pass |
| scorecard tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-scorecard-proof.ps1` | pass |
| scorecard validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .` | pass |
| repo validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` | pass |
| live sync validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` | pass |
| version freshness | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent` | pass |
| tracker align proof | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` | pass |
| cleanup | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` | pass |
| clean git state | `git status --short --branch` | pass |

## Source Artifact Links

- `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`
- `docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md`
- `docs/superpowers/workflow-contract.yml`
- `docs/superpowers/loop-mode-contract.yml`
- `docs/superpowers/backlog/ACTIVE.md`
- `docs/superpowers/examples/workflow-golden-paths.md`
- `docs/superpowers/examples/worker-handoff-packets.md`
- `skills/loop-controller/scripts/validate-loop-state-machine.ps1`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/OUTCOME_WORKFLOW.md`
- `README.md`

## Looping Mode Proof

- `docs/superpowers/loop-mode-contract.yml` documents phase order, one-candidate iterations, budget rechecks, source precedence, Auto Mode separation, and final Done invariants.
- `skills/loop-controller/scripts/validate-loop-state-machine.ps1` validates loop state ledgers.
- `skills/loop-controller/scripts/test-scenarios.ps1` covers one-candidate, no-auto-drain, no-ready, Auto Mode misuse, budget exhaustion, dirty repo, owner mismatch, and historical-checkbox fixtures.
- `docs/superpowers/examples/workflow-golden-paths.md` shows the strict Looping Mode flow and state-machine proof stop point.

## Live Sync And Tracker Proof

- `scripts/sync-live.ps1 -Validate` is the live install proof command.
- `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent` is the version freshness proof command.
- `skills/align-project/scripts/align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` is the tracker hygiene proof command.
- `docs/superpowers/milestones/M0-governance.md` links this receipt.
- `docs/superpowers/milestones/M1-source-of-truth.md` links this receipt.

## Project Context Roles

- `docs/superpowers/workflow-contract.yml` is the route contract for material native gates and exact option shape.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface, not the route authority.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence for orchestrated work.
- `docs/superpowers/milestones/*receipt*.md` files are validation receipts and milestone history.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs. `.chatgpt/**` is handoff input; `.superpowers/**` is generated runtime evidence.
