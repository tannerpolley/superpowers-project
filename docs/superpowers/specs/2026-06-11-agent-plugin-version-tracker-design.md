# Agent Plugin Version Tracker Design

## Purpose

Agents need a source-owned way to prove which Superpowers Project plugin copy they are using. The manifest version alone is too soft because skill text, metadata, assets, or helper scripts can change without a version bump. The tracker defines exact runtime identity as:

- plugin manifest name and version;
- source git commit when available;
- source dirty state;
- deterministic runtime `contract_hash` over `.codex-plugin/plugin.json`, `skills/`, `assets/`, `scripts/lib/`, and `scripts/get-agent-plugin-version.sh`.

## Design

Add `scripts/get-agent-plugin-version.sh` as the canonical checker. It reads the source repo, deployed live plugin root, optional observed plugin or skill root, and local Codex cache candidates. It emits JSON with `ok`, `phase`, `reason`, `source`, `live`, `observed`, `cache_candidates`, `stale_cache_candidate_count`, `current_agent_known`, and `recommended_recovery`.

The checker is strict only when `-RequireCurrent` is supplied. In strict mode, source/live drift or observed-agent drift exits nonzero. Stale unobserved cache candidates are still reported, but they do not fail the run unless the stale candidate is passed as `-ObservedPluginRoot` or resolved from `-ObservedSkillRoot`.

## Live Distribution

`scripts/sync-live.sh` copies the checker into the live plugin under `scripts/get-agent-plugin-version.sh`. `scripts/lib/live-install.sh` compares that file during live drift checks so a stale or missing live checker fails validation.

Validated live sync also refreshes matching local plugin cache roots when they already exist. This is an update propagation mechanism for existing threads and agents that re-read skill bodies from their materialized cache copy. It is not a durable contract on cache paths, and it cannot rewrite prompt text or skill text already loaded into the active model context.

Use `-SkipCacheRefresh` only for deliberately live-only validation or diagnosis.

## Agent Usage

At Superpowers Project startup, agents print the human-readable version banner:

```bash
./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
```

Agents can run:

```bash
./scripts/get-agent-plugin-version.sh -RequireCurrent
```

When an agent has a loaded skill root from its active context, it should prove that exact loaded copy:

```bash
./scripts/get-agent-plugin-version.sh -ObservedSkillRoot <loaded-skill-root> -RequireCurrent
```

## Recovery

If live differs from source, run:

```bash
./scripts/sync-live.sh --validate
```

If live matches source but the observed plugin root differs, validated live sync refreshes matching local plugin cache roots. If the observed root still differs after sync, start a fresh agent session so Codex reloads the plugin cache.

## Validation

- `./scripts/test-agent-plugin-version.sh`
- `./scripts/test-plugin-only-live-sync.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
