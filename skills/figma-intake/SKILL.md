---
name: figma-intake
description: Read Figma nodes through Figma MCP and generate design_spec.json following pipeline/contracts/design_spec.schema.json.
---

# Figma Intake

Use this skill when a user provides Figma URLs/node IDs and needs design context for implementation.

## Input
- Figma file URL
- Node IDs (or infer from URL)

## Output
- `design_spec.json` compliant with `pipeline/contracts/design_spec.schema.json`

## Workflow
1. Fetch design context for selected nodes.
2. Extract node specs, states, interactions, sizing, assets.
3. Add responsive constraints when available.
4. Mark missing details with `MISSING:`.
5. Mark inferred details with `ASSUMPTION:`.

## Constraints
- Prioritize exact design evidence from MCP over assumptions.
- Do not force code generation in this step.
