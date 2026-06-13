---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update the local HTML companion report for rich artifact review.
---

# Companion Interface

Companion Interface is the Superpowers Project evidence and interpretation channel. It writes repo-scoped report sessions and renders a static HTML workbench for the Codex in-app browser.

Use this skill when the user asks to show rich artifacts, when a workflow produces large specs or plans, or when implementation evidence includes plots, tables, validation receipts, screenshots, diagrams, or long summaries.

## Approval Boundary

The companion must not record approval, push, publish, merge, live sync, GitHub mutation, or final Done. Native Codex chat and `request_user_input` remain the decision authority.

## Report Model

Use `scripts/new-report-session.ps1` to create a session, `scripts/append-event.ps1` to add structured evidence, and `scripts/render-report.ps1` to regenerate `index.html`.

Generated reports live under `.superpowers/reports/<yyyy-mm-dd>/<run-id>`.

## Required Closeout

After updating a report, tell the user the exact `index.html` path and the artifact types added. Keep chat concise and point detailed review to the companion.
