# Pipeline Contracts v1

These schemas define the handoff format between agents in the Jira/Figma/GitLab pipeline.

## Shared conventions
- `contract_version`: must be `1.0.0`
- `unknowns[]`: every item must start with `MISSING:`
- `assumptions[]`: every item must start with `ASSUMPTION:`
- Source-of-truth priority:
  1. Jira acceptance criteria
  2. Figma node specifications
  3. Existing repository patterns

## Files
- `ticket_spec.schema.json`: output of `jira-intake`
- `design_spec.schema.json`: output of `figma-intake`
- `implementation_brief.schema.json`: output of `spec-filler`
- `implementation_result.schema.json`: output of `dev-executor`
- `qa_result.schema.json`: output of `ui-fidelity-qa` / `qa-retro`
