# Active Backlog

This file is the explicit Loop Controller candidate source for current maintenance work. Historical plan checkboxes, generated run ledgers, and closed issue mirrors are not active backlog entries.

| ID | Route owner | Source artifact | Priority | Status | Proof target | Reason |
|---|---|---|---|---|---|---|
| 71 | resolve-issue | docs/superpowers/issues/71-golden-path-workflow-fixtures.md | P2 | ready | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1` | Unblocked by #70; golden-path workflow fixtures are next. |
| 72 | resolve-issue | docs/superpowers/issues/72-live-sync-tracker-align-validation.md | P2 | blocked | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` | Final proof slice blocked by #71 golden-path workflow fixtures. |
