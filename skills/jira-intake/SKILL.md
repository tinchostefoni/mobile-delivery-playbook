---
name: jira-intake
description: >
  Read a Jira issue through Atlassian MCP and generate a structured ticket_spec
  following the ticket_spec JSON schema. Triggers when processing a Jira ticket
  as part of the pipeline or when the user provides a Jira key/URL for intake.
allowed-tools: Bash, Read, Write
---

# Jira Intake

Use this skill when a user provides Jira links/keys and wants structured intake.

## Input
- Jira issue key(s) or URL(s)
- Optional user constraints

## Output
- `ticket_spec.json` compliant with `contracts/ticket_spec.schema.json`

## Workflow
1. Resolve key from URL when needed.
2. Fetch issue details from Atlassian MCP.
3. Populate business context, scope, AC, technical hints, references.
4. Mark unknown data with `MISSING:`.
5. Mark inferred decisions with `ASSUMPTION:`.
6. Validate output against `contracts/ticket_spec.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Constraints
- Do not invent missing facts.
- Keep output aligned to real Jira data, not assumptions unless tagged.
- **Jira is READ-ONLY.** Never write, comment, transition, assign, or mutate any Jira issue in any way.
  Any Atlassian MCP calls must be read operations only. This restriction applies unconditionally.
