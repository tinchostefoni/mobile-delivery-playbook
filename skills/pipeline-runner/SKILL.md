---
name: pipeline-runner
description: Orchestrate the Jira+Figma pipeline end-to-end from a single payload block. Trigger when the user writes @pipeline-runner and provides JIRA/FIGMA/REPO fields.
---

# Pipeline Runner

Use this skill when the user wants to run the canonical pipeline from a single message.

## Trigger phrase
- `@pipeline-runner`

## Expected input block

```md
JIRA_KEY: <KEY>
JIRA_URL: <URL>
FIGMA_URL: <URL or empty if not applicable>
FIGMA_NODE_IDS: <ids or empty if not applicable>
REPO_PATH: <absolute path>
TARGET_BASE_BRANCH: <dev|develop|development>
NOTIFY_GOOGLE_CHAT: <true|false>
```

Optional execution mode:
- `RUN_MODE: DRY_RUN` (default)
- `RUN_MODE: REAL_RUN`

## Orchestration order
1. Run `jira-intake` -> `ticket_spec.json`
2. Run `figma-intake` when Figma fields are provided -> `design_spec.json`
3. Run `spec-filler` -> `implementation_brief.json`
4. Run `dev-executor` -> code changes + `implementation_result.json`
5. Run local/relevant tests and QA gate checks
6. Update changelog from real code diff
7. Run `qa-retro` -> `qa_result.json`
8. Send Google Chat notifications per workflow policy

## Command gating
- Never auto-commit, auto-push, or auto-merge by default.
- After `READY_FOR_REVIEW`, wait for explicit user command:
  - `EFFECTIVIZE_COMMIT`
  - `CREATE_MR`
  - `EFFECTIVIZE_COMMIT_AND_CREATE_MR`

## Error policy
- Attempt autonomous retries and fixes first.
- Emit `ERROR_BLOCKING` only when retries are exhausted or blocked by external dependencies.

## Source of truth
- Follow:
  - `/Users/martinstefoni/Documents/Martín/pipeline/workflow.md`
  - `/Users/martinstefoni/Documents/Martín/pipeline/contracts/*.schema.json`

## Output expectations
- Keep user informed with concise progress updates.
- Produce/refresh pipeline artifacts in workspace (`ticket_spec`, `design_spec`, `implementation_brief`, `implementation_result`, `qa_result`).
