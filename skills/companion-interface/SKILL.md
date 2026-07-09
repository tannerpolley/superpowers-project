---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update repo-owned Agent-Native visual-plan or visual-recap MDX artifacts for rich review.
---

# Companion Interface

Create an optional visual review surface. It complements canonical specs, plans, and receipts; it never replaces native approval or becomes project truth.

## Capability Preflight

Require `filesystem.read` and `filesystem.write` from `docs/superpowers/capabilities.yml`. Use `browser` only for requested preview and `native.user-input` only for route choice. Stop before writing when a required capability is absent.

## Shared Policy

Use `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This route keeps only route-specific companion artifacts and preview evidence. Route connections live in `docs/superpowers/workflow-contract.yml`.

## Artifact Contract

Create a repo-owned folder containing `plan.mdx` or a visual recap, with optional `canvas.mdx` or `prototype.mdx`. Link the canonical Markdown sources, keep claims grounded in those files, and mark any derived status explicitly. Do not embed credentials or treat preview state as permission to mutate, publish, push, or merge.

Use local-files tooling first. Start a preview only when requested, report its exact URL and lifecycle, and stop the process before closeout. A preview failure does not invalidate the canonical source artifact.

## Closeout

Show the companion folder, artifact kind, linked source paths, preview result, and representative content. Then return to the owning route. Use `Stop` only through the shared intermediate gate; this skill has no verified final `Done` state.
