# GitHub Sub-Issues Workflow Examples

These examples show how Superpowers Project issue creation should use GitHub Milestones plus native parent/sub-issue links. Issue titles stay clean; milestone names, milestone numbers, hierarchy ordinals, and pseudo sub-milestone numbers belong in GitHub fields and local mirror metadata.

## Flat Issue

Use `flat` mode for one executable issue or unrelated executable issues.

```markdown
# Hydrate External Issue Mirrors

**GitHub Milestone:** M1 - Source Of Truth
**Hierarchy Mode:** flat
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** None
**Child Issues:** None
**Rollup Policy:** none
**Title Policy:** Clean GitHub title
```

Publication receipt:

```powershell
gh issue create --title "Hydrate External Issue Mirrors" --milestone "M1 - Source Of Truth" --label "type:task" --label "status:ready"
```

## Issue Set

Use `issue-set` mode when one parent groups a small set of executable leaves.

Parent mirror:

```markdown
# Create Issues Workflow

**GitHub Milestone:** M1 - Source Of Truth
**Hierarchy Mode:** issue-set
**Sub-Issue Role:** parent
**Executable:** false
**Parent Issue:** None
**Child Issues:** https://github.com/example/repo/issues/22, https://github.com/example/repo/issues/23
**Rollup Policy:** all-required-children-closed
**Title Policy:** Clean GitHub title
```

Leaf publication receipt:

```powershell
gh issue create --title "Hydrate External Issues" --milestone "M1 - Source Of Truth" --label "type:task" --label "status:ready" --parent "https://github.com/example/repo/issues/21"
```

## Pseudo Sub-Milestone

Use `sub-milestone` mode when a large parent issue acts as a pseudo sub-milestone inside a real GitHub Milestone.

```text
GitHub Milestone: M1 - Source Of Truth
Parent issue: GitHub Sub-Issues Workflow
Plan wrapper: Create Issues
Leaves: Hierarchy Schema And Validators, Publication Hydration And Routing
```

Dry publication order:

```powershell
gh issue create --title "GitHub Sub-Issues Workflow" --milestone "M1 - Source Of Truth" --label "type:sub-milestone"
gh issue create --title "Create Issues" --milestone "M1 - Source Of Truth" --label "type:plan-wrapper" --parent "https://github.com/example/repo/issues/30"
gh issue create --title "Hierarchy Schema And Validators" --milestone "M1 - Source Of Truth" --label "type:task" --label "status:ready" --parent "https://github.com/example/repo/issues/31"
gh issue create --title "Publication Hydration And Routing" --milestone "M1 - Source Of Truth" --label "type:task" --label "status:ready" --parent "https://github.com/example/repo/issues/31"
```

## External Hydration

Hydration reads GitHub JSON fields and writes local mirror metadata before execution routing.

```powershell
gh issue view 42 --json body,parent,subIssues,subIssuesSummary,milestone,labels,issueType,title,url,number
```

Hydrated leaf mirror:

```markdown
# Publication Hydration And Routing

**GitHub Issue:** https://github.com/example/repo/issues/42
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Labels:** type:task, status:ready
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** https://github.com/example/repo/issues/31
**Parent Mirror:** docs/superpowers/issues/31-create-issues.md
**Child Issues:** None
**Rollup Policy:** none
**Title Policy:** Clean GitHub title
```

## Selective Migration

When historical issues encode milestone identity in titles, do not bulk rename. `align-project` should report migration candidates and require native approval before any GitHub mutation.

```text
Candidate title drift: M1: Create Issues Routing
Proposed clean title: Create Issues Routing
Tracker source: GitHub Milestone M1 - Source Of Truth plus parent/sub-issue links
Required approval: native migration gate before rename or attachment
```
