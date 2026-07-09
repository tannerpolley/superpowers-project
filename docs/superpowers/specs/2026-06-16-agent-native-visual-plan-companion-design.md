# Agent-Native Visual Plan Companion Replacement Design

## Purpose

Replace the static HTML companion direction with BuilderIO/Agent-Native visual-plan artifacts whose durable source is repo-owned MDX.

The Superpowers Project workflow still needs a rich evidence and review surface for specs, plans, issue evidence, validation receipts, diagrams, screenshots, plots, tables, and long summaries. The replacement changes the surface from generated HTML reports under `.superpowers/reports` to structured Agent-Native Plan folders under `plans/<slug>/`, with `plan.mdx` as the source of truth and optional `canvas.mdx` or `prototype.mdx` when visual UI review is actually needed.

Native Codex chat and `request_user_input` remain the only approval and continuation authority. Visual plans show evidence, decisions, recommendations, and open questions, but they do not approve push, publish, merge, live sync, GitHub mutation, or final Done.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines this repository as the durable project workflow layer for specs, plans, issue mirrors, milestone pages, GitHub linkage, and native goal execution.
- `README.md` defines the main workflow as a chain of native Codex questions. Each skill summarizes what it produced, asks `Continue?`, and starts the selected next route.
- `README.md` requires artifacts to be shown before closeout, push, publish, or merge questions. The replacement keeps that gate, but the rich review surface becomes Agent-Native MDX instead of generated HTML.
- `skills/companion-interface/SKILL.md` currently describes a static HTML workbench, report sessions, `manifest.json`, `events.jsonl`, and generated `index.html`.
- `docs/superpowers/specs/2026-06-12-superpowers-html-companion-interface-design.md` and `docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md` implemented an HTML direction that is now superseded by this spec.
- `scripts/test-companion-interface.sh` and `skills/companion-interface/scripts/test-scenarios.sh` currently assert HTML companion contracts. A follow-up implementation plan must rewrite those checks around MDX source, local preview, and native approval boundaries.
- The fresh Codex thread does not expose hosted Plan MCP tools such as `create-visual-plan`, `get-plan-blocks`, `read-visual-plan-source`, `patch-visual-plan-source`, or `export-visual-plan`.
- The local Agent-Native CLI can fetch the block catalog and supports local-files privacy mode, which writes repo-owned `plans/<slug>/plan.mdx` and previews it with `npx @agent-native/core@latest plan local preview --dir plans/<slug> --kind plan --open`.

## User Decisions

- Continue through `$superpowers-project:initiate-workflow` in Auto Mode for this one route.
- Route the work through `$superpowers-project:brainstorm-spec` with `superpowers:brainstorming`.
- Use BuilderIO/Agent-Native visual-plan artifacts instead of extending the static HTML companion.
- If hosted Plan MCP tools are available in a fresh session, use the hosted visual-plan flow. In this session they are not available, so use local-files privacy mode.
- Do not loop on hosted authentication. The prior reconnect attempts reached device-code display but failed polling with HTTP 404 at the device poll endpoint.
- Edit the Superpowers Project repo source only. Do not edit deployed plugin copies or plugin cache files.

## Problem Statement

The HTML companion solved a real problem, but it added a second local artifact renderer inside the Superpowers Project plugin. That direction now conflicts with the Agent-Native planning stack the user selected:

- HTML report sessions make generated `index.html`, `manifest.json`, and `events.jsonl` the review bundle, while the desired durable review source is MDX.
- The static renderer duplicates work that Agent-Native Plans already owns: structured blocks, diagrams, file maps, question forms, local preview, and optional hosted collaboration.
- HTML report scripts introduce another local rendering surface to maintain and validate.
- The current `companion-interface` skill language keeps teaching agents to create HTML reports even when the intended artifact should be a visual-plan folder.
- Approval boundaries are easy to blur when a browser workbench starts looking like a control panel. The replacement should make the boundary explicit: visual plan equals evidence and review; native Codex equals approval.

## Recommended Approach

Replace `companion-interface` in place with an Agent-Native visual-plan artifact workflow.

The route name can remain `$superpowers-project:companion-interface` because existing Superpowers Project skills already use it as the rich artifact review route. Its behavior should change from "create or refresh a static HTML report" to "create or refresh a repo-owned Agent-Native Plan folder." The implementation should remove the HTML report scripts and templates instead of keeping a pass-through wrapper.

The durable source contract is:

```text
plans/<slug>/
  plan.mdx
  canvas.mdx        # optional, only when static UI review is useful
  prototype.mdx     # optional, only when interaction review is useful
  .plan-state.json  # optional local preview/editor state
```

The canonical Superpowers Project spec and implementation plan remain under `docs/superpowers/specs/` and `docs/superpowers/plans/`. The `plans/<slug>/` root is specifically the Agent-Native local-files review artifact root requested for visual plans. It does not replace Superpowers implementation plans.

## Designs Considered

### Design 1: Agent-Native MDX Companion

`companion-interface` creates or refreshes `plans/<slug>/plan.mdx`, optionally adds visual surfaces, runs local preview, and reports the MDX path plus local preview route.

Strengths:

- Matches the selected BuilderIO/Agent-Native direction.
- Keeps the review artifact source-controlled and portable.
- Uses native plan blocks for diagrams, file maps, decisions, tables, code, and open questions.
- Removes the plugin-owned HTML renderer and its validation burden.
- Preserves native Codex approvals.

Tradeoffs:

- Requires the Agent-Native CLI for local preview.
- Hosted comments and sharing remain unavailable until hosted Plan tools are authenticated and visible in the active session.
- Existing HTML companion tests and documentation need a deliberate migration.

Recommendation: choose this design.

### Design 2: Hosted Plan MCP First

Use hosted Plan MCP tools by default and export MDX only when needed.

Strengths:

- Best collaboration surface when tools are loaded and authenticated.
- Enables comments, sharing, source reads, patches, and exports through MCP tools.

Tradeoffs:

- The current Codex session exposes no hosted Plan tools.
- Prior auth setup failed at device polling, and blindly retrying it would waste time.
- Hosted Plan storage cannot be the required source of truth for repo-owned workflow artifacts.

Recommendation: keep as an optional publish/review transport after tool availability is proven, not the required path.

### Design 3: HTML Shell Around Agent-Native MDX

Keep the static HTML companion but embed or link Agent-Native MDX artifacts inside it.

Strengths:

- Could preserve some of the just-built scripts.
- Might ease short-term transition for agents already trained on `index.html` reports.

Tradeoffs:

- Keeps two review surfaces and two validation contracts.
- Violates the desired replacement by leaving HTML companion assumptions in place.
- Adds indirection without improving approval provenance.

Recommendation: reject this design.

## Product Shape

When a governed workflow produces large artifacts, the agent creates a local Agent-Native plan folder and reports:

- the repo-local source path, such as `plans/brainstorm-agent-native-companion/plan.mdx`
- the local preview URL or route returned by Agent-Native preview
- the canonical Superpowers artifact path, such as `docs/superpowers/specs/<date>-<slug>.md`
- a concise native-chat summary and the next native continuation gate

The reviewer sees a structured visual plan with:

- objective and done criteria
- project context evidence
- recommended approach and rejected alternatives
- file map for the implementation route
- architecture/data-flow diagrams
- validation and sync receipts
- open questions only when answers would change the plan

The reviewer still answers approvals in Codex chat or native `request_user_input`.

## Architecture

### Companion Skill Contract

`skills/companion-interface/SKILL.md` should be rewritten around Agent-Native local-files mode:

- Description: create or refresh repo-owned Agent-Native visual-plan MDX artifacts for rich review.
- Approval boundary: visual plans never record approval, publish, merge, live sync, GitHub mutation, or final Done.
- Source model: `plans/<slug>/plan.mdx` is the durable visual-plan source. Optional `canvas.mdx` and `prototype.mdx` are present only when visual UI review needs them.
- Preview model: run `npx @agent-native/core@latest plan local preview --dir plans/<slug> --kind plan --open` after writing or revising a plan folder.
- Hosted model: if Plan MCP tools are visible, the agent may use hosted creation/publishing, but exported or local MDX remains the repo-owned source when the workflow requires local ownership.
- Failure model: if hosted tools are missing, do not retry auth loops. Use local-files mode. If the CLI cannot preview, fail loudly with the command and error.

### Removed HTML Contract

The implementation should delete or fully retire:

- `skills/companion-interface/scripts/new-report-session.sh`
- `skills/companion-interface/scripts/append-event.sh`
- `skills/companion-interface/scripts/render-report.sh`
- `skills/companion-interface/scripts/lib/companion-report.sh`
- `skills/companion-interface/templates/report-template.html`
- `skills/companion-interface/templates/report.css`
- `skills/companion-interface/templates/report.js`
- static report-session assumptions under `.superpowers/reports/<date>/<run-id>`
- tests that assert `index.html`, `manifest.json`, or `events.jsonl`

Do not replace these with pass-through wrappers. The behavior should move to MDX source and Agent-Native preview.

### Data Flow

1. A governed workflow decides the artifact review would benefit from a richer surface than chat.
2. The agent identifies or creates a slug under `plans/<slug>/`.
3. The agent fetches the Agent-Native block catalog with a schema-only command or available MCP `get-plan-blocks`.
4. The agent writes or patches `plan.mdx` and optional visual files.
5. The agent runs local preview and records the returned local route or failure.
6. The agent shows the canonical Superpowers artifact and the Agent-Native source path before any continuation or permission question.
7. The user reviews the visual plan and answers through Codex chat or `request_user_input`.

## Integration Points

### `brainstorm-spec`

Replace "HTML companion" opt-in guidance with Agent-Native visual-plan guidance. The visual plan should include context evidence, Design 1/2/3 alternatives, user decisions, open questions, saved spec path, and recommended next route.

### `write-plan`

Use a visual plan when an implementation plan is large enough that task lists, use cases, file maps, proof oracles, and validation receipts need structured review. The canonical implementation plan still lives under `docs/superpowers/plans/`.

### `audit-project` And `align-project`

Use visual plans for dense findings, drift maps, repair options, and verification receipts. P-coded findings remain in Markdown specs when they are canonical project artifacts.

### `implement-plan`, `resolve-issue`, `orchestrate-issues`, And `merge-changes`

Use visual plans for evidence inventory, changed-file maps, validation receipts, branch/PR proof, and closeout review. The visual plan does not replace issue mirrors, goal ledgers, PRs, or merge gates.

## Validation Expectations

Validation should prove:

- `companion-interface` no longer describes a local HTML report or static `index.html` workbench.
- Plugin README and default prompt describe Agent-Native visual-plan MDX artifacts instead of HTML reports.
- Tests reject stale phrases such as "local HTML companion report", "generated `index.html`", `.superpowers/reports`, `manifest.json`, and `events.jsonl` in active companion-interface guidance.
- A fixture `plans/<slug>/plan.mdx` can be created and previewed locally.
- The visual-plan artifact includes project evidence, alternatives, file map, validation expectations, and native approval boundary.
- Hosted Plan MCP absence routes to local-files mode without repeated auth attempts.
- `scripts/validate.sh` passes.
- `scripts/sync-live.sh --validate` passes before reporting live install readiness.
- The cleanup hook reports no repo-owned leftover processes.

## Proof Oracle Candidates

- Focused companion contract test asserts `skills/companion-interface/SKILL.md`, README, plugin prompt, and skill metadata use Agent-Native visual-plan wording.
- Focused scenario test creates a fixture plan folder under `plans/fixture-agent-native-companion/`, writes `plan.mdx`, runs local preview, and confirms the command exits or reports a usable local route.
- Stale HTML contract test scans active companion-interface guidance and fails on static report-session vocabulary.
- Full repo validation passes.
- Live sync validation passes.
- Cleanup hook passes.

## Migration Plan Shape

A future implementation plan should use a narrow, source-first migration:

1. Update tests to fail on active HTML companion wording and require Agent-Native MDX wording.
2. Rewrite `skills/companion-interface/SKILL.md` and metadata.
3. Remove HTML report scripts and templates.
4. Add a minimal local visual-plan scenario fixture.
5. Update `brainstorm-spec` and `write-plan` opt-in guidance.
6. Update README, plugin prompt, contract summary generation if needed, and project context.
7. Run focused tests, full validation, live sync validation, and cleanup.

## Trust And Safety Boundaries

- Visual plans do not approve, publish, push, merge, live sync, mutate GitHub, or record final Done.
- Native Codex chat and `request_user_input` remain the decision channel.
- Hosted Plan tools may be used only when visible and authenticated in the active session.
- Local-files mode must not send plan content to hosted Plan services.
- The CLI block catalog lookup is allowed because it sends no repo plan content.
- Failure to preview a plan must be reported directly. Do not fake a local URL or silently substitute an HTML report.

## Milestone Linkage

- `M0 - Governance`: native approval boundaries, continuation gates, validation contracts, and stale HTML wording prevention.
- `M1 - Source Of Truth`: repo-owned MDX visual-plan source, canonical Superpowers artifact roots, and source/live alignment.
- `M2 - Distribution`: Agent-Native CLI expectations, hosted-tool recovery guidance, and install validation after the replacement is implemented.

## Non-Goals

- Do not repair hosted Agent-Native authentication in this spec.
- Do not introduce a new HTML wrapper around MDX plans.
- Do not keep the HTML report scripts as an alternate execution path.
- Do not replace canonical Superpowers specs, plans, issue mirrors, or milestone pages.
- Do not make visual plans the approval authority.
- Do not create GitHub issues from this spec without a later explicit planning route.

## Open Questions

No blocking product decisions remain for the replacement direction. The implementation plan can still choose exact test fixture names and the smallest helper shape for creating local MDX plans.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently treats Agent-Native MDX as the review source and native Codex as the approval channel.
- Scope check: this is one implementation-plan-sized migration: replace one companion route, update tests/docs, remove HTML scripts, and validate live sync.
- Ambiguity check: hosted Plan MCP is explicitly optional and not required for the repo-owned path.
