# Active Backlog

This file is the explicit Loop Controller candidate source for current maintenance work. Historical plan checkboxes, generated run ledgers, and closed issue mirrors are not active backlog entries.

| ID | Route owner | Source artifact | Priority | Status | Proof target | Reason |
|---|---|---|---|---|---|---|
| 69 | resolve-issue | docs/superpowers/issues/69-artifact-review-card-schema.md | P2 | ready | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1` | Standardize Artifact Review Card schema after native continuation policy is centralized. |
| 70 | resolve-issue | docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md | P2 | blocked | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1` | Blocked by #69 artifact review card schema. |
| 71 | resolve-issue | docs/superpowers/issues/71-golden-path-workflow-fixtures.md | P2 | blocked | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1` | Blocked by #69 artifact review card schema. |
| 72 | resolve-issue | docs/superpowers/issues/72-live-sync-tracker-align-validation.md | P2 | blocked | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` | Final proof slice blocked by #68 through #71. |
