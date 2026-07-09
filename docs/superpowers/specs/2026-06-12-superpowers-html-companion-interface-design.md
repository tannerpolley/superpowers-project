# Superpowers HTML Companion Interface Design

## Purpose

Introduce a Superpowers Project companion interface that uses the Codex in-app browser as a live HTML workbench for agent-to-user reporting.

The companion should keep the main chat interface small and procedural while moving long-form evidence, rendered Markdown artifacts, plots, tables, math, validation output, summaries, and review context into a browser-rendered report surface.

This is not a replacement for native Codex chat or `request_user_input`. Chat remains the control channel. The HTML companion is the evidence and interpretation channel.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines this repository as the durable project workflow layer for specs, plans, issue mirrors, milestone pages, GitHub linkage, and native goal execution.
- `docs/superpowers/PROJECT_CONTEXT.md` says GoalBuddy boards are outside the default execution model, which means this companion should not revive the old board as the execution authority.
- `README.md` defines the main workflow as a chain of native Codex questions. Each skill summarizes what it produced, asks `Continue?`, and starts the selected next route.
- `README.md` requires artifacts to be shown before closeout, push, publish, or merge questions. This companion should become the natural display surface for that artifact review gate.
- `docs/superpowers/specs/2026-06-04-closeout-artifact-review-and-plan-metrics-design.md` already requires an artifact inventory, findings summary, result interpretation, active-goal impact, broader project impact, and recommended next route.
- `docs/assets/native-qa-main-flow-preview.html` proves the repo already accepts lightweight HTML assets that can be opened in a browser for visual review.
- `scripts/generate-contract-summary.sh` already generates deterministic Markdown from repo source. The companion should use the same source-driven philosophy: structured inputs first, rendered output second.
- `docs/superpowers/milestones/M0-governance.md` owns workflow contracts, validation policy, and guardrails. The companion touches M0 because it changes the closeout evidence surface.
- `docs/superpowers/milestones/M1-source-of-truth.md` owns source/live skill alignment and artifact layout. The companion touches M1 because it must preserve canonical Markdown and JSON artifacts while adding rendered HTML views.

## External Research Evidence

- [ATV-PaperBoard](https://github.com/All-The-Vibes/ATV-PaperBoard) is the closest external pattern. It renders agent outputs as HTML artifacts, persists sidecar metadata, and builds a gallery. Useful ideas: artifact triples, generated gallery, render/persist/compound workflow, and harness-aware paths.
- [MD Activator](https://github.com/khtwo/md-activator) is a local-first Markdown workflow UI. Useful ideas: browse local Markdown as rendered pages, show checkboxes and progress, render Mermaid, and make `.md` artifacts easier for humans to inspect.
- [AG-UI](https://docs.ag-ui.com/introduction) is a broader event protocol for agent-user applications. Useful idea: use typed events for runs, artifacts, state, and UI updates. The Superpowers companion should borrow the event idea without adopting the full protocol for v1.
- [Open WebUI artifact discussion](https://github.com/open-webui/open-webui/discussions/3487) captures the same user experience need: separate complex artifacts from the main conversation so users are not forced to scroll through large chat dumps.
- [Arize coding harness tracing](https://arize.com/blog/open-source-coding-agent-tracing/) shows the value of step-by-step run inspection for coding agents. Useful ideas: run timeline, commands, files, tool activity, retries, and final outputs. The Superpowers companion should keep this human-facing rather than turning it into a telemetry product.
- The attached Markdown-to-HTML research answer is directionally correct that browsers do not natively render raw Markdown as structured HTML. For this feature, Markdown conversion should be deliberate and support Pandoc, MathJax, code highlighting, diagrams, and local media.

## User Decisions

- Use the `Design 1: Live Companion` direction.
- The companion should be a live in-app browser page, not only a checkpoint report.
- The page may support lightweight interaction such as collapsing and expanding sections.
- The page should not become a full control panel for approvals, merges, pushes, or repo mutations.
- Native Codex chat and native user-input prompts remain the authority for decisions and approvals.
- The main chat UI should show commands being run, small process updates, and short change summaries.
- Large outputs, rich summaries, results, rendered specs, rendered plans, issue mirrors, plots, tables, tests, screenshots, diagrams, and validation evidence should be shown in the HTML companion.
- Markdown should remain the canonical source format for specs, plans, issues, and docs where this repo already uses Markdown.
- HTML should be the human review and presentation surface over those source artifacts.
- The companion is similar to the old Goal Buddy Board only in that it is a persistent visual surface. It should not be a task-only board. It should show the full workbench: evidence, artifacts, interpretation, review context, and workflow state.

## Problem Statement

The current Superpowers Project workflow asks the agent to show artifacts and explain results in chat. That works for small artifacts but becomes strained when the agent produces:

- long specs, plans, and issue bodies
- implementation summaries across many files
- validation receipts and command output
- plots, screenshots, SVGs, and tables
- mathematical notation
- Mermaid diagrams and flowcharts
- before/after comparisons
- multi-stage issue-resolution evidence
- merge readiness proof

Markdown in chat is useful for compact status, but it is a poor medium for dense review. It makes the chat transcript long, visually flat, and hard to scan. It also mixes three separate concerns in one surface:

- process status
- decision prompts
- detailed evidence review

The companion should split those concerns cleanly. Chat stays concise and procedural. The browser companion becomes the readable evidence workspace.

## Recommended Approach

Build a Superpowers-specific live HTML companion powered by a structured report manifest.

The agent should write structured report events and artifacts during a workflow run. A renderer should convert those events and artifact references into an HTML page opened in the Codex in-app browser. The page should update as the run progresses and provide a durable report bundle for later review.

Markdown conversion is an important feature, but not the whole architecture. The companion should treat Markdown as one artifact type among several. Plots, tables, validation receipts, diagrams, command results, file inventories, and risk summaries need typed representation so they can be rendered better than a single Markdown document.

## Designs Considered

### Design 1: Live Companion

The agent maintains one browser page for the active run. It appends structured events to a manifest and writes referenced artifacts under a report directory. The page refreshes or polls the manifest and shows the current workflow state.

Strengths:

- best match for the requested experience
- keeps chat minimal throughout the work, not only at the end
- supports plots, tables, rendered Markdown, validation evidence, and summaries in one place
- can become the normal artifact review gate surface
- preserves native Codex prompts as the approval channel

Tradeoffs:

- requires a small local renderer or static page with polling
- needs clear rules for report paths and generated artifact cleanup
- needs validation so skill closeouts do not skip required evidence

Recommendation: choose this design.

### Design 2: Closeout Report Generator

The agent writes a polished HTML report only at natural checkpoints such as after a spec, plan, implementation, audit, or merge.

Strengths:

- simpler than a live companion
- lower runtime complexity
- easy to add to current artifact review gates

Tradeoffs:

- does not solve the live-work visibility problem
- chat may still carry too much detail while work is underway
- less useful during long implementation or issue-resolution runs

Recommendation: keep as a mode or stepping stone, not the design center.

### Design 3: Markdown-First HTML Converter

The agent writes one rich Markdown report and converts it to HTML with Pandoc and MathJax.

Strengths:

- fastest to build
- fits the repo's existing Markdown roots
- easy to review in git

Tradeoffs:

- weak for multi-artifact runs, plots, tables, and validation receipts
- turns the browser into "chat Markdown in another place" rather than a real companion
- makes it harder to show typed evidence, file inventories, and workflow state

Recommendation: use Markdown conversion inside the companion, but do not make it the whole system.

## Companion Product Shape

The companion should be a local, repo-scoped workbench with these top-level areas:

- **Run Overview:** current skill, branch, goal or issue, workflow route, started time, current phase, and recommended next route.
- **Workflow Timeline:** brainstorm, spec, plan, issue creation, implementation, validation, merge, live sync, and cleanup events.
- **Artifact Browser:** specs, plans, issue mirrors, milestone pages, reports, receipts, plots, screenshots, and tables.
- **Evidence Feed:** command results, validation output, test summaries, cleanup proof, branch proof, PR links, and generated ledgers.
- **Interpretation Summary:** what changed, what was fixed, what remains risky, what the results mean, active-goal impact, project impact, and next recommendation.
- **Decision Dock:** pending native decision context, shown read-only in the companion while actual answering stays in Codex native input.
- **Gallery:** prior companion reports grouped by date, workflow, branch, issue, or goal.

## Core Features

### Live Report Manifest

The companion should use a machine-readable manifest as the source of truth for the HTML report.

Candidate files:

- `manifest.json` for current report state
- `events.jsonl` for append-only event history
- `artifacts/` for files referenced by the report
- `report.html` or `index.html` for the rendered browser entrypoint

Candidate report entry types:

- `run_started`
- `phase_started`
- `phase_completed`
- `artifact_added`
- `artifact_changed`
- `markdown_rendered`
- `plot_added`
- `table_added`
- `command_result`
- `validation_result`
- `test_result`
- `file_inventory`
- `risk_added`
- `summary_added`
- `decision_needed`
- `decision_recorded`
- `cleanup_result`
- `run_completed`

Each event should include enough metadata to render it and trace it back to the repo source:

- event id
- timestamp
- skill name
- workflow phase
- title
- severity or status when relevant
- source path
- artifact path
- summary text
- structured payload for tables, commands, or validation

### Rendered Markdown Artifacts

The companion should render existing Markdown artifacts without replacing them.

Artifacts to render:

- specs under `docs/superpowers/specs/`
- plans under `docs/superpowers/plans/`
- issue mirrors under `docs/superpowers/issues/`
- milestone pages under `docs/superpowers/milestones/`
- generated summaries and audit findings
- selected README or contract-summary excerpts when relevant

Rendering should support:

- YAML frontmatter displayed separately
- headings with anchors
- GitHub-flavored tables
- task lists
- fenced code blocks with syntax highlighting
- Mermaid diagrams
- MathJax for equations
- local images and SVGs
- source path links

Pandoc should be the planned Markdown conversion engine for the production companion. If a first implementation slice uses a narrower renderer to prove the manifest and browser workflow, the plan must state that scope directly and still preserve the Pandoc target for the production path.

### Plot And Table Gallery

Implementation and analysis-heavy workflows often produce plots and tables that are awkward in chat. The companion should first-class these artifacts.

Plot support:

- PNG, SVG, JPG, and PDF previews when feasible
- captions and source commands
- generated timestamp
- related source file or script
- associated validation metric
- side-by-side comparisons for before/after plots

Table support:

- CSV, TSV, JSON arrays, and Markdown tables
- sortable columns as a later enhancement
- status coloring for pass/fail/warn rows
- compact summary plus expandable raw data
- units and tolerances when present

### Validation And Test Receipts

The companion should make validation evidence easy to scan.

Display fields:

- command
- working directory
- exit code
- duration
- result status
- focused summary
- key stdout or stderr excerpt
- linked full log path when a full log is saved
- related skill or plan task

The page should distinguish:

- focused tests
- full repo validation
- live sync validation
- cleanup hook proof
- branch or PR proof
- plan exactness proof
- issue mirror validation

### Changed Artifact Inventory

For implementation, issue resolution, and merge workflows, the companion should show a clear changed-artifact inventory.

Inventory fields:

- path
- artifact type
- action: created, changed, deleted, verified, or generated
- owning task or workflow phase
- short summary
- validation coverage
- review priority

This should support the current policy that artifacts must be shown before push or merge decisions.

### Collapsible Evidence Sections

The companion should support basic interaction:

- expand/collapse sections
- jump-to-section anchors
- copy path or command buttons
- filter by status or artifact type as a later enhancement

The companion should not require complex editing or write-back behavior in v1.

### Decision Dock

The companion should show decision context without becoming the decision authority.

Display examples:

- pending question id
- prompt
- available native options
- recommended route
- artifact evidence that must be reviewed first
- why the recommendation was made

The actual answer should still be submitted through native Codex `request_user_input` or the main chat. This keeps approval provenance clean.

### Goal Buddy Boundary

The companion may show tasks, but it must not become a task-only board.

Allowed task-state display:

- current plan tasks
- task status
- evidence attached to each task
- validation attached to each task
- issue or branch linkage

Required broader display:

- artifact browser
- evidence feed
- interpretation summary
- validation receipts
- plots and tables
- source links
- decision context

The companion is a workbench report, not a replacement Goal Buddy Board.

## Data Flow

1. A Superpowers Project workflow skill starts or reaches a reporting point.
2. The agent or helper script creates a report session directory.
3. The workflow writes structured events to `events.jsonl` and current state to `manifest.json`.
4. Human-readable artifacts remain in canonical repo roots such as `docs/superpowers/specs/`, `docs/superpowers/plans/`, and `docs/superpowers/issues/`.
5. Generated companion-only assets land under the report session directory.
6. The renderer converts Markdown, plots, tables, and validation summaries into HTML sections.
7. Codex opens or refreshes the in-app browser at the report entrypoint.
8. The agent keeps chat updates short and points to the companion for detailed evidence.
9. Before any continuation, push, publish, merge, or final gate, the companion report must contain the required artifact review evidence.
10. Native Codex input remains the approval and continuation mechanism.

## Suggested File Layout

The exact root can be chosen during planning, but the layout should be repo-scoped and easy to clean.

Candidate checked-in source:

- `skills/companion-interface/SKILL.md`
- `skills/companion-interface/agents/openai.yaml`
- `skills/companion-interface/scripts/render-companion.sh`
- `skills/companion-interface/scripts/append-event.sh`
- `skills/companion-interface/templates/index.html`
- `skills/companion-interface/templates/report.css`
- `skills/companion-interface/templates/report.js`
- `scripts/test-companion-interface.sh`

Candidate generated output:

- `.superpowers/reports/<yyyy-mm-dd>/<run-id>/manifest.json`
- `.superpowers/reports/<yyyy-mm-dd>/<run-id>/events.jsonl`
- `.superpowers/reports/<yyyy-mm-dd>/<run-id>/index.html`
- `.superpowers/reports/<yyyy-mm-dd>/<run-id>/artifacts/`

If generated output should be checked into git for selected reports, that should be a deliberate workflow decision. Routine active-run reports should be generated workspace artifacts rather than canonical specs, plans, or issue mirrors.

## Skill Integration

### `brainstorm-spec`

The companion should show:

- project context evidence used
- Design 1, Design 2, and optional Design 3 alternatives
- user decisions
- open questions
- saved spec preview
- recommendation and next route

This directly reduces chat load during design-heavy brainstorming.

### `write-plan`

The companion should show:

- source spec links
- task list with use cases
- exact files and commands
- proof oracle
- test-complete criteria
- metric thresholds and tolerances when relevant
- plan validation receipts

This should make long implementation plans reviewable without filling chat with hundreds of lines.

### `create-issues`

The companion should show:

- issue mirror previews
- GitHub issue links when created
- AFK/HITL classification
- dependency map
- blockers
- validation results

### `implement-plan`

The companion should show:

- task progress
- changed file inventory
- implementation summaries
- test receipts
- plots, tables, and screenshots
- risks and unresolved items
- branch proof and push readiness evidence

### `resolve-issue`

The companion should show:

- issue mirror
- source plan
- task execution evidence
- changed files
- tests and validation
- PR-ready or merge-ready proof

### `orchestrate-issues`

The companion should show:

- worker thread identity
- worktree and branch identity
- per-worker status
- handoff evidence
- implementation and review summaries
- integration readiness

### `merge-changes`

The companion should show:

- premerge proof
- changed artifact inventory
- validation results
- branch and PR proof
- merge decision context
- closeout cleanup proof
- final health evidence

### `audit-project` And `align-project`

The companion should show:

- P-coded findings
- blocking, repairable, informational, and healthy checks
- evidence snippets
- proposed repairs
- skipped checks
- repair receipts when approved repairs run

## Error Handling

The companion must fail loudly when report generation cannot produce the required evidence surface.

Examples:

- If Markdown rendering fails, show the source path, render command, exit code, and error excerpt in the companion and in a short chat update.
- If a plot path is missing, show the missing artifact entry as a broken evidence item rather than silently omitting it.
- If a validation command fails, show the failure status and key output in the validation section.
- If the browser page cannot be opened, still write the report bundle and report the exact path in chat.
- If the manifest is invalid, block companion closeout evidence and report the schema error.

The system should not invent default success states when evidence is missing.

## Trust And Safety Boundaries

- The companion must not authorize push, publish, merge, live sync, GitHub mutation, or final Done.
- Native Codex input and explicit chat instructions remain the approval channel.
- The companion may show recommended routes, but it must not record approval without native or chat proof.
- Generated HTML should treat repo-authored content as local trusted content, but scripts should be minimal and local.
- External CDNs should be avoided for default rendering. MathJax, Mermaid, and syntax highlighting assets should be bundled or locally resolved when practical.
- The companion should avoid sending local code, logs, or artifacts to remote services.

## Validation Expectations

Validation should prove:

- companion report sessions can be created from a sample manifest
- Markdown specs, plans, and issue mirrors render to HTML
- YAML frontmatter is displayed separately from rendered body
- MathJax and Mermaid examples render in the browser page
- plot and table artifacts appear with captions and source links
- validation receipts show command, exit code, status, and key output
- changed artifact inventories are represented in the report
- pending decision context is displayed without recording approval
- generated report paths stay within the intended repo-scoped report directory
- governed skill closeout text can reference the companion artifact review gate without weakening native continuation rules
- cleanup can remove or ignore generated report runtime artifacts according to repo policy

## Proof Oracle Candidates

- A fixture manifest renders to a valid `index.html`.
- A fixture Markdown spec with frontmatter, code blocks, Mermaid, MathJax, and tables renders correctly.
- A fixture plot and CSV table appear in the gallery.
- A fixture validation failure appears as a failed receipt with command and excerpt.
- A fixture changed-file inventory appears with action, summary, and validation coverage.
- A fixture pending decision appears in the Decision Dock but does not create an approval ledger.
- `./scripts/validate.sh` passes after implementation.
- `./scripts/sync-live.sh --validate` passes before live deployment is reported complete.
- The repo cleanup hook reports no leftover processes owned by the companion server or renderer.

## Milestone Linkage

- `M0 - Governance`: companion evidence gates, native decision boundaries, validation receipts, and approval provenance.
- `M1 - Source Of Truth`: canonical Markdown and JSON artifacts remain source, while HTML reports are generated views.
- `M2 - Distribution`: later packaging should document companion dependencies, browser behavior, report paths, and install validation.

## Non-Goals

- Do not replace native Codex chat.
- Do not replace `request_user_input`.
- Do not make the HTML page the approval authority.
- Do not turn the companion into a task-only Goal Buddy Board.
- Do not make report HTML the canonical source of specs, plans, or issues.
- Do not require rich editing or write-back behavior in the first version.
- Do not use remote services for default local report rendering.
- Do not hide missing evidence behind invented success states.

## Open Questions For Planning

- Should the companion be a new `companion-interface` skill, a shared helper used by existing workflow skills, or both?
- Should generated reports live under `.superpowers/reports/`, `docs/superpowers/reports/`, or another repo-scoped path?
- Should live updates use browser polling of `manifest.json`, a lightweight local server, or static regeneration plus refresh?
- Should Pandoc be required for v1, or should v1 support a smaller renderer with Pandoc as the preferred production target?
- Which report artifacts should be retained after a run, and which should be treated as cleanup-owned runtime output?
- Should the report gallery include all local reports by default or only reports explicitly marked for retention?
- Should companion output be enabled by default for all governed skills or opt-in until validation proves it stable?

## Recommended First Implementation Slice

The first implementation plan should avoid boiling the ocean. A strong v1 slice would include:

1. A report manifest schema with event types for artifacts, command results, summaries, decisions, plots, and tables.
2. A static HTML renderer that reads one fixture manifest and writes a self-contained `index.html`.
3. Markdown rendering for specs, plans, and issue mirrors with frontmatter separation.
4. Plot and table display from local files.
5. Validation receipt display.
6. A report gallery for the current repo.
7. A `brainstorm-spec` or `write-plan` integration proving the companion can reduce chat artifact dumping.
8. Focused tests plus full repo validation.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently treats Markdown and JSON as durable source formats and HTML as the human review surface.
- Scope check: the feature is large, but the recommended first slice is narrow enough to become one implementation plan.
- Ambiguity check: open questions are planning choices about packaging, generated paths, live refresh mechanics, and retention policy. They do not block the core product direction.
