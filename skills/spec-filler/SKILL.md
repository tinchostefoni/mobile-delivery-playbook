---
name: spec-filler
description: >
  Merge ticket_spec and design_spec into an implementation_brief
  following the implementation_brief JSON schema. Creates a dev-ready
  implementation plan with work items mapped to acceptance criteria.
allowed-tools: Bash, Read, Write
---

# Spec Filler

Use this skill to create a dev-ready implementation brief.

## Input
- `ticket_spec.json`
- `design_spec.json` (optional if task has no UI)
- Repo constraints/patterns

## Output
- `implementation_brief.json` compliant with `contracts/implementation_brief.schema.json`

## Workflow
1. Merge Jira + Figma + repo constraints.
2. Create actionable work_items mapped to AC and node IDs.
3. Enforce `no_auto_commit: true`.
4. Build validation plan (unit/integration/UI as relevant).
5. Preserve unresolved items as `MISSING:` and assumptions as `ASSUMPTION:`.
6. Validate output against `contracts/implementation_brief.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.
