---
name: spec-filler
description: Merge ticket_spec.json and design_spec.json into implementation_brief.json following pipeline/contracts/implementation_brief.schema.json.
---

# Spec Filler

Use this skill to create a dev-ready implementation brief.

## Input
- `ticket_spec.json`
- `design_spec.json` (optional if task has no UI)
- Repo constraints/patterns

## Output
- `implementation_brief.json` compliant with `pipeline/contracts/implementation_brief.schema.json`

## Workflow
1. Merge Jira + Figma + repo constraints.
2. Create actionable work_items mapped to AC and node IDs.
3. Enforce `no_auto_commit: true`.
4. Build validation plan (unit/integration/UI as relevant).
5. Preserve unresolved items as `MISSING:` and assumptions as `ASSUMPTION:`.
