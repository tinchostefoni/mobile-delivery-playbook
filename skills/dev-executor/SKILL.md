---
name: dev-executor
description: Implement code from implementation_brief.json and produce implementation_result.json with validations and changelog evidence.
---

# Dev Executor

Use this skill for implementation execution.

## Input
- `implementation_brief.json`

## Output
- Code changes
- `implementation_result.json` compliant with `pipeline/contracts/implementation_result.schema.json`

## Workflow
1. Implement work_items incrementally.
2. Run required tests/checks.
3. Update `CHANGELOG.md` under `Unreleased` from real code diff (past tense, Keep a Changelog sections).
4. Capture validation evidence and changed files.
5. Fill `implementation_result.changelog` fields.

## Constraints
- Never auto-commit, auto-push, or auto-merge by default.
- Commit and MR creation are allowed only after explicit user command in chat.
