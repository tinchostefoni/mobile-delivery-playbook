# Technical Reference

This document contains implementation-level details for `playbook-setup` and `pipeline-runner`.

## 1) Configuration model

Project configuration is stored in:
- `<REPO_ROOT>/.codex/playbook.config.yml`

Optional auto-context files:
- `<REPO_ROOT>/.codex/project_context.auto.md`
- `<REPO_ROOT>/.codex/project_context_paths.auto.txt`

### Setup modes
- `SETUP_MODE=INIT`
  - Requires `REPO_PATH`.
  - Creates initial config and optional auto-detected context files.
- `SETUP_MODE=UPDATE`
  - Updates existing setup values.
  - If `REPO_PATH` is omitted, it uses `project.repo_path` saved by `INIT`.
  - If saved `project.repo_path` is missing, setup fails.

## 2) Input contracts

### `playbook-setup` payload
Core fields:
- `SETUP_MODE: INIT|UPDATE`
- `REPO_PATH` (required for `INIT`, optional for `UPDATE`)
- `PROJECT_NAME`
- `JIRA_PROJECT_KEY`
- `JIRA_BASE_URL`
- `FIGMA_BASE_URL`
- `ARCHITECTURE_OVERRIDE` (optional, explicit architecture source of truth)
- `TARGET_BASE_BRANCH`
- `NOTIFY_GOOGLE_CHAT`
- `AUTO_DETECT_CONTEXT`
- `WRITE_ARTIFACTS`
- `ARTIFACTS_PATH` (required only when `WRITE_ARTIFACTS=true`)

### `pipeline-runner` payload
Core fields:
- `JIRA_KEY` (required)
- `FIGMA_NODE_IDS` (optional, required for UI work)
- `RUN_MODE: REAL_RUN|DRY_RUN|PLAN_ONLY` (default: `REAL_RUN`)
- `TECH_CONTEXT` (optional, task-specific)

## 3) Context precedence

Effective values are resolved in this order:
1. Runtime payload (only allowed runtime fields)
2. `<REPO_ROOT>/.codex/playbook.config.yml`
3. Runner defaults

Context loading:
- Task-level context: `TECH_CONTEXT` from runtime payload.
- Project-level context: setup config + auto-context files under `.codex/`.
- If `context.architecture_override` is set, architecture wording uses that value and does not rely on detector inference.

## 4) Branch safety behavior

For `REAL_RUN`, runner must execute:
1. checkout `TARGET_BASE_BRANCH`
2. `git pull -r`
3. create/switch to working branch

Implementation on base branch is not allowed.

## 5) Preflight behavior

Script:
- [scripts/preflight_pipeline_runner.sh](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/scripts/preflight_pipeline_runner.sh)

Output modes:
- `text` (human-readable)
- `json` (machine-readable)

JSON shape:
- `status`
- `code`
- `field`
- `message`
- `warnings` (array)

Blocking policy highlights:
- Invalid/missing Jira data: block.
- Missing setup config: block.
- Missing context paths configured by setup: block.
- `WRITE_ARTIFACTS=true` without writable `ARTIFACTS_PATH`: block.
- Missing/invalid `JIRA_BASE_URL`: block.
- Missing/invalid `FIGMA_BASE_URL` when `FIGMA_NODE_IDS` exists: block.
- Base branch missing locally but present remotely: warning, not block.
- Base branch missing locally and remotely: block.

## 6) Run summary integration

Generator:
- [scripts/generate_run_summary.sh](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/scripts/generate_run_summary.sh)

Default output:
- `<REPO_ROOT>/.codex/pipeline-runner/<JIRA_KEY>/run_summary.md`

When it is incorporated in the flow:
- `PLAN_ONLY`: generated when planning finishes, before completion notification (`PLAN_ONLY_DONE`).
- `REAL_RUN` / `DRY_RUN`: generated at pipeline close with execution/validation state, before final user handoff.
- On blocking outcomes, summary should still be generated with blockers and next action.

Mode-aware content:
- `PLAN_ONLY`: plan, forecast files, risks/unknowns, next action.
- `REAL_RUN` / `DRY_RUN`: scope, changed files, validations, blockers, next action.

## 7) Artifacts behavior

Artifacts are controlled by setup config, not per run payload.

- `WRITE_ARTIFACTS=false`:
  - Keep contracts/results in memory unless explicitly needed.
- `WRITE_ARTIFACTS=true`:
  - Persist to `ARTIFACTS_PATH` (recommended `<REPO_ROOT>/.codex/pipeline-runner`).

## 8) Notifications

Google Chat notifier script:
- [scripts/notify_google_chat.sh](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/scripts/notify_google_chat.sh)

Events:
- `ACTION_REQUIRED`
- `PLAN_ONLY_DONE`
- `READY_FOR_REVIEW`
- `CI_PENDING`
- `CI_FAILED`
- `ERROR_BLOCKING`
- `FINALIZED`

`ERROR_BLOCKING` should be sent only after autonomous retry/repair attempts are exhausted.
