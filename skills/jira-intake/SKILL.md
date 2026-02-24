---
name: jira-intake
description: Read a Jira issue through Atlassian MCP and generate ticket_spec.json following pipeline/contracts/ticket_spec.schema.json.
---

# Jira Intake

Use this skill when a user provides Jira links/keys and wants structured intake.

## Input
- Jira issue key(s) or URL(s)
- Optional user constraints

## Output
- `ticket_spec.json` compliant with `pipeline/contracts/ticket_spec.schema.json`

## Workflow
1. Resolve key from URL when needed.
2. Fetch issue details from Atlassian MCP.
3. Populate business context, scope, AC, technical hints, references.
4. Mark unknown data with `MISSING:`.
5. Mark inferred decisions with `ASSUMPTION:`.

## Constraints
- Do not invent missing facts.
- Keep output aligned to real Jira data, not assumptions unless tagged.
