---
name: dev-executor
description: >
  Implement code changes from an implementation_brief and produce an
  implementation_result with validations and changelog evidence.
  Triggers during the implementation phase of the pipeline.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Dev Executor

Use this skill for implementation execution.

## Input
- `implementation_brief.json`

## Output
- Code changes
- `implementation_result.json` compliant with `contracts/implementation_result.schema.json`

## Workflow
1. Implement work_items incrementally.
2. Run required tests/checks.
3. Update `CHANGELOG.md` under `Unreleased` from real code diff (past tense, Keep a Changelog sections).
4. Capture validation evidence and changed files.
5. Fill `implementation_result.changelog` fields.
6. Validate output against `contracts/implementation_result.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Constraints
- Never auto-commit, auto-push, or auto-merge by default.
- Commit and MR creation are allowed only after explicit user command in chat.
