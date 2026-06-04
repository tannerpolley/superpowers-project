# Fix audit-project repo detection and concise issue mirror drift checks Plan

**Source:** https://github.com/tannerpolley/superpowers-project/issues/39
**Issue Mirror:** docs/superpowers/issues/39-fix-audit-project-repo-detection-and-concise-issue-mirror-drift-checks.md

## Goal

Make `audit-project` GitHub-aware mode inspect the intended repository reliably and report concise issue mirrors without noisy false positives or fake repairability.

## Scope

- `skills/audit-project/scripts/audit-project.ps1`
- `skills/audit-project/scripts/test-scenarios.ps1`
- Generated issue mirror for issue 39

## Implementation Steps

1. Add failing scenario tests that cover:
   - `target_repo` roadmap metadata.
   - `repository` roadmap metadata remaining supported.
   - `git remote` fallback when roadmap metadata is absent.
   - frontmatter `title` parsing for issue mirrors.
   - H1 parsing after YAML frontmatter.
   - concise mirrors matching GitHub metadata without containing the complete body.
   - mirror drift being informational/manual rather than repairable when no repair receipt is generated.

2. Update repository slug resolution in `audit-project.ps1`:
   - prefer `repository`;
   - accept `target_repo`;
   - fall back to parsing `git remote get-url origin`;
   - normalize common HTTPS and SSH GitHub remote formats to `owner/repo`;
   - keep the output field name `target_repo` for compatibility.

3. Update issue mirror parsing:
   - parse YAML frontmatter only enough to read a `title` value;
   - otherwise read the first Markdown H1 after frontmatter;
   - fall back to the filename slug only if no title exists.

4. Update mirror drift comparison:
   - keep URL/number, title, milestone, and labels as structured drift checks;
   - do not require exact GitHub body containment for concise mirrors;
   - if future full-body mirrors are introduced, gate exact body comparison behind an explicit mirror mode instead of making it the default.

5. Update mirror drift category semantics:
   - report mirror metadata drift as informational/manual unless `-ApplyTrackerRepairs` creates a concrete repair receipt;
   - keep genuinely repairable tracker hygiene findings unchanged.

6. Run validation:
   - audit-project scenario tests;
   - full repo validation;
   - live sync validation.

## Verification

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```
