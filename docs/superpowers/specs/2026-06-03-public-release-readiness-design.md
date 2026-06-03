# Public Release Readiness Design

## Project Context Evidence

Superpowers Project is now the active plugin identity in `.codex-plugin/plugin.json`, and the source skill set is already organized under `skills/` with `superpowers-project`, `project-setup`, `project-brainstorm`, `project-plan`, `project-issue`, `project-resolve`, `project-orchestrate`, `project-merge`, and `project-doctor`.

The repo is still named and hosted as `tannerpolley/milestones-plugin`, and GitHub reports it is private. The current quick implementation is explicitly limited to docs and scripts; it must not rename the GitHub repo, rename the local workspace folder, mutate GitHub visibility, or rewrite historical issue/PR links.

Current public-readiness gaps found during inspection:

- `README.md` explains the workflow but lacks a public-facing install story and still describes the live target as `C:\Users\Tanner\plugins\milestones`.
- `scripts/sync-live.ps1` still deploys the live plugin copy to `C:\Users\Tanner\plugins\milestones`.
- `skills/project-doctor/scripts/audit-project.ps1` still treats `plugins/milestones` as the live plugin sync surface.
- `.github/ISSUE_TEMPLATE/*.yml` still says "Milestones plugin" and points users to deleted `docs/milestones/...` paths.
- `.codex-plugin/plugin.json` lacks public repository, homepage, license, and keyword metadata.
- `docs/superpowers/PROJECT_CONTEXT.md`, `docs/agents/issue-tracker.md`, and `docs/agents/project-roadmap.json` still use the current private repo name as operational tracker state. Those should remain unchanged until the repo is actually renamed.

## User Decisions

- Public-facing identity target: `codex-superpowers-project`.
- Quick implementation scope: docs and scripts only.
- Do not rename the GitHub repo or local workspace folder in this quick pass.
- Do not make the GitHub repo public in this quick pass.

## Recommended Approach

Treat `codex-superpowers-project` as the public package and future GitHub repo identity while preserving the current operational tracker path until the rename actually happens.

The quick implementation should:

- keep manifest `name` as `superpowers-project`, because skill routing already uses that stable plugin identity;
- add public manifest metadata that points at the intended public repository URL;
- change the default live plugin install target to `C:\Users\Tanner\plugins\superpowers-project`;
- remove stale owned skills from the retired `C:\Users\Tanner\plugins\milestones` live path when syncing;
- update Doctor live-sync checks to inspect the new live plugin path and report the retired path when it still exists;
- update README install/share guidance for clone-based local installation;
- update issue templates to say Superpowers Project and point to `docs/superpowers/issues/...`;
- keep historical docs and closed GitHub links untouched unless they are active instructions.

## Tradeoffs

This avoids the risk of renaming the live GitHub repo and local workspace in a quick pass, but it means the README must clearly say the current GitHub repository may still be `milestones-plugin` until the public rename occurs.

Changing the live plugin folder to `plugins\superpowers-project` makes the local install match the new public identity. Keeping a retired cleanup path for `plugins\milestones` prevents stale live copies from shadowing or confusing future installs.

## Non-Goals

- Do not rename the GitHub repository.
- Do not rename the local workspace folder.
- Do not make the GitHub repository public.
- Do not rewrite closed issue or PR history links.
- Do not create a GitHub release or tag.
- Do not change the issue tracker repository fields until the actual GitHub rename happens.

## Milestone Linkage

- M1 - Source Of Truth: live plugin path, manifest metadata, and stale path cleanup.
- M2 - Distribution: public installation, release/share readiness, and GitHub issue templates.

## Proof Oracle Candidates

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `Test-Path "$env:USERPROFILE\plugins\superpowers-project\.codex-plugin\plugin.json"`
- `Test-Path "$env:USERPROFILE\plugins\milestones"`
- `rg -n "Milestones plugin|docs/milestones|plugins\\milestones|plugins/milestones" README.md .github`
- `Select-String -Path .\scripts\sync-live.ps1,.\skills\project-doctor\scripts\audit-project.ps1 -Pattern "plugins\\superpowers-project|plugins/superpowers-project"`

## Open Questions

- When ready for a real public release, decide whether to rename the GitHub repo to `codex-superpowers-project` and update `docs/agents/*` plus historical-forward links.
- Decide whether to add screenshots or a short video/GIF before posting to Reddit.
- Decide whether to publish a formal release tag after the public rename.
