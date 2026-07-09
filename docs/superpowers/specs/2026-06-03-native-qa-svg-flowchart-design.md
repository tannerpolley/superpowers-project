# Native Q&A SVG Flowchart Design

## Purpose

Revise the public README flowchart so it is visually clear, deterministic, dark-mode readable, and accurate enough to explain the main Superpowers Project native Q&A workflow.

This spec is intentionally docs/visual-only. It does not add or revise plugin skill behavior. Skill behavior changes belong in the separate Project Implement and integration workflow spec.

## Project Context Evidence

- The README is the public entry point for the plugin.
- The current visible flowchart is now an SVG at `docs/assets/native-qa-main-flow.svg`.
- Mermaid was useful for quick iteration but cannot reliably enforce exact fixed-coordinate layout rules such as identical skill-box x positions, local stop node placement, and precise revise-arrow re-entry points.
- The IDE can preview SVG, but dark mode originally hid arrows when the SVG relied on page background instead of owning its own theme-aware canvas.

## Decisions Made

- Use SVG as the canonical visible README flowchart.
- Remove the archived Mermaid diagram from the README; it should not compete with the public SVG.
- Keep decision questions inside diamond nodes.
- Put answer choices on arrows.
- Keep all primary skill boxes in one centered vertical column.
- Put all Stop nodes on the right side as local stop nodes.
- Put all gray alternate-action boxes on the left side.
- Make revise arrows leave from the left point of the decision diamond and return to the side of the originating skill box.
- Make shared default/downward decisions stem from the bottom point of the decision diamond before branching.
- Make the SVG readable in light and dark mode by controlling the SVG background, arrow color, label color, and arrowhead color.

## Required Layout Rules

- Blue skill boxes share identical `x`, `width`, and horizontal center.
- The main default path is a single top-to-bottom spine.
- Main default arrows leave from the bottom point of each decision diamond.
- Branch labels sit consistently near their outgoing arrows.
- Stop nodes are all on the right and local to the decision that produced them.
- Gray alternate-action boxes are all on the left.
- Revise arrows leave the left point of the relevant decision diamond and enter the side of the originating skill box.
- No connector crosses through node text.
- No node overlaps another node.
- The diagram must render legibly in GitHub and local IDE dark mode.

## Scope

In scope:

- `README.md` flowchart embed.
- `docs/assets/native-qa-main-flow.svg`.
- Optional docs text around the diagram.
- Validation or smoke checks that enforce the SVG exists and uses theme-aware styles.

Out of scope:

- Adding `project-implement`.
- Changing `write-plan`, `resolve-issue`, `orchestrate-issues`, or `merge-changes`.
- Bundling `advanced-user-input`.
- Implementing Doctor tracker hygiene.
- Changing runtime native Q&A behavior.

## Proof Oracle Candidates

- README references `docs/assets/native-qa-main-flow.svg`.
- README no longer contains the archived full Mermaid flowchart.
- SVG exists under `docs/assets`.
- SVG contains a theme-aware background, arrow color, label color, and arrowhead color.
- SVG smoke check confirms all blue skill boxes use the same x position and width.
- SVG smoke check confirms Stop nodes are right of the main column.
- SVG smoke check confirms gray alternate-action boxes are left of the main column.
- Playwright screenshot checks render the SVG in light and dark mode.
- `scripts/validate.sh` passes.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: this spec is visual/docs-only and does not carry plugin behavior changes.
- Scope check: this can be planned and implemented independently from skill behavior.
- Ambiguity check: the main unresolved visual judgment is exact final positioning, which belongs in the visual implementation task.

