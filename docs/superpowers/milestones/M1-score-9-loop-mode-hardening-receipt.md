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
| workflow contract tests | `./scripts/test-workflow-contract.sh` | pass |
| workflow contract validator | `./scripts/validate-workflow-contract.sh -RepoRoot .` | pass |
| metadata tests | `./scripts/test-skill-metadata-contract.sh` | pass |
| metadata validator | `./scripts/validate-skill-metadata-contract.sh -RepoRoot .` | pass |
| loop controller tests | `./scripts/test-loop-controller.sh` | pass |
| loop scenarios | `./skills/loop-controller/scripts/test-scenarios.sh` | pass |
| scorecard tests | `./scripts/test-scorecard-proof.sh` | pass |
| scorecard validator | `./scripts/validate-scorecard-proof.sh -RepoRoot .` | pass |
| repo validation | `./scripts/validate.sh` | pass |
| live sync validation | `./scripts/sync-live.sh --validate` | pass |
| version freshness | `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent` | pass |
| tracker align proof | `./skills/align-project/scripts/align-project.sh -RepoRoot . -Mode GitHubAware -TrackerHygiene` | pass |
| cleanup | `"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .` | pass |
| clean git state | `git status --short --branch` | pass |

## Source Artifact Links

- `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`
- `docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md`
- `docs/superpowers/workflow-contract.yml`
- `docs/superpowers/loop-mode-contract.yml`
- `docs/superpowers/backlog/ACTIVE.md`
- `docs/superpowers/examples/workflow-golden-paths.md`
- `docs/superpowers/examples/worker-handoff-packets.md`
- `skills/loop-controller/scripts/validate-loop-state-machine.sh`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/OUTCOME_WORKFLOW.md`
- `README.md`

## Looping Mode Proof

- `docs/superpowers/loop-mode-contract.yml` documents phase order, one-candidate iterations, budget rechecks, source precedence, Auto Mode separation, and final Done invariants.
- `skills/loop-controller/scripts/validate-loop-state-machine.sh` validates loop state ledgers.
- `skills/loop-controller/scripts/test-scenarios.sh` covers one-candidate, no-auto-drain, no-ready, Auto Mode misuse, budget exhaustion, dirty repo, owner mismatch, and historical-checkbox fixtures.
- `docs/superpowers/examples/workflow-golden-paths.md` shows the strict Looping Mode flow and state-machine proof stop point.

## Live Sync And Tracker Proof

- `scripts/sync-live.sh --validate` is the live install proof command.
- `scripts/get-agent-plugin-version.sh -Banner -RequireCurrent` is the version freshness proof command.
- `skills/align-project/scripts/align-project.sh -RepoRoot . -Mode GitHubAware -TrackerHygiene` is the tracker hygiene proof command.
- `docs/superpowers/milestones/M0-governance.md` links this receipt.
- `docs/superpowers/milestones/M1-source-of-truth.md` links this receipt.

## Project Context Roles

- `docs/superpowers/workflow-contract.yml` is the route contract for material native gates and exact option shape.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface, not the route authority.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence for orchestrated work.
- `docs/superpowers/milestones/*receipt*.md` files are validation receipts and milestone history.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs. `.chatgpt/**` is handoff input; `.superpowers/**` is generated runtime evidence.
