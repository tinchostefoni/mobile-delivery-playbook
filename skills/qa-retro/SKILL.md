---
name: qa-retro
description: >
  Evaluate implementation outputs, verify merge gates (tests, QA, changelog),
  and produce a qa_result following the qa_result JSON schema.
  Triggers after implementation and testing phases of the pipeline.
allowed-tools: Bash, Read, Write
---

# QA Retro

Use this skill after implementation and testing.

## Input
- `implementation_result.json`
- QA evidence/results
- CI test status

## Output
- `qa_result.json` compliant with `contracts/qa_result.schema.json`

## Workflow
1. Validate checks and regressions.
2. Set merge gates:
- `all_tests_green`
- `qa_approved`
- `changelog_updated`
3. Set `mergeable=true` only if all gates are true.
4. Provide clear recommendation (`ready_for_review`, `needs_changes`, or `blocked`).
5. Validate output against `contracts/qa_result.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Constraints
- If any test fails, block.
- QA approval does not replace CI green status.
