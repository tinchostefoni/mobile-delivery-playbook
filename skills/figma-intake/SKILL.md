---
name: figma-intake
description: >
  Read Figma nodes through Figma MCP and generate a structured design_spec
  following the design_spec JSON schema. Triggers when processing Figma designs
  as part of the pipeline or when the user provides Figma URLs/node IDs.
allowed-tools: Bash, Read, Write
---

# Figma Intake

Use this skill when a user provides Figma URLs/node IDs and needs design context for implementation.

## Input
- Figma file URL
- Node IDs (or infer from URL)

## Output
- `design_spec.json` compliant with `contracts/design_spec.schema.json`

## Workflow
1. Fetch design context for selected nodes.
2. Extract node specs, states, interactions, sizing, assets.
3. Add responsive constraints when available.
4. Mark missing details with `MISSING:`.
5. Mark inferred details with `ASSUMPTION:`.
6. Validate output against `contracts/design_spec.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Constraints
- Prioritize exact design evidence from MCP over assumptions.
- Do not force code generation in this step.
