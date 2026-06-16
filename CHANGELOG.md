# Changelog

## Unreleased

- Added a deployed Auto Mode authorization validator script so project repos can validate bounded Auto Mode ledgers through the plugin surface instead of requiring a repo-local helper.
- Added source-owned operational maturity tooling for contract summaries, stale skill detection, release receipts, local branch closeout, and local workflow smoke coverage.
- Added agent plugin version tracking with manifest version plus runtime content hashes for source, live install, observed plugin roots, and local cache candidates.
- Added a startup version banner contract and validated sync propagation for matching existing local plugin cache candidates.
- Added a strict Task # Use Cases gate for plan creation, plan implementation, and linked issue resolution.
- Added the source contract for `$superpowers-project:loop-controller`.
- Added Loop Controller budget validation and deterministic candidate selection contracts.
- Added Loop Controller verifier, terminal closeout, and metrics contracts.
- Strengthened plugin validation wiring and CI entry points for manual and pull-request validation.

## 0.2.0 - 2026-06-02

- Started the Superpowers Project migration.
- Renamed plugin metadata from Milestones to Superpowers Project.
- Moved the target artifact contract to `docs/superpowers`.

## 0.1.0 - 2026-06-02

- Created canonical source repository for the Milestones plugin.
- Added source-controlled plugin manifest, canonical skill folders, validation scripts, live sync scripts, issue templates, and milestone docs.
- Established `docs/milestones/<milestone-folder>/ideas/` and `docs/milestones/<milestone-folder>/issues/` as the durable local artifact model.
