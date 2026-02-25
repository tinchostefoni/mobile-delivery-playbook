---
name: pipeline-runner
description: Orchestrate the Jira+Figma pipeline end-to-end from a single payload block using canonical workflow and contracts.
---

# Pipeline Runner

Use this skill when the user wants to run the canonical pipeline from a single message.

## Trigger phrase
- Recommended invocation: plain text (`Use pipeline-runner with this payload:`)
- `@pipeline-runner` is optional and may not be available in all contexts

## Expected input block

```md
JIRA_KEY: <KEY>
FIGMA_NODE_IDS: <ids or empty if not applicable>
RUN_MODE: REAL_RUN|DRY_RUN|PLAN_ONLY

# optional, task-specific context
TECH_CONTEXT: |
  Task-level technical notes, constraints, backend contracts.
```

## Defaults
- `RUN_MODE`: `REAL_RUN`
- `RUN_SUMMARY_PATH`: `<REPO_ROOT>/.codex/pipeline-runner/<JIRA_KEY>/run_summary.md`

## Config resolution
1. Resolve `REPO_ROOT` from current working directory (`git rev-parse --show-toplevel`).
2. Auto-load `<REPO_ROOT>/.codex/playbook.config.yml`.
3. If config is missing, fail with explicit message: run `playbook-setup` first.
4. If available, read additional auto-context files:
   - `<REPO_ROOT>/.codex/project_context.auto.md`
   - `<REPO_ROOT>/.codex/project_context_paths.auto.txt`
5. Apply values with precedence:
   - explicit payload fields
   - setup config fields
   - runner defaults
6. If setup config includes `project.jira_project_key`, validate `JIRA_KEY` prefix against it.
7. Use global settings from setup config (not runtime payload):
   - `project.repo_path`
   - `integrations.jira_base_url`
   - `integrations.figma_base_url`
   - `pipeline.auto_detect_context`
   - `pipeline.write_artifacts`
   - `pipeline.artifacts_path`
   - `context.project_context_paths`
8. Build derived links:
   - `JIRA_URL = <jira_base_url>/browse/<JIRA_KEY>`
   - `FIGMA_URL = <figma_base_url>?node-id=<first FIGMA_NODE_ID>` (when node ids are provided)

## Preflight requirements (mandatory)
0. Run preflight validator before any implementation step:
   - `<PLAYBOOK_ROOT>/scripts/preflight_pipeline_runner.sh`
   - Use `--output-format json` when machine-readable diagnostics are needed.
1. Load canonical workflow and contracts from playbook repo:
   - `<PLAYBOOK_ROOT>/workflow.md`
   - `<PLAYBOOK_ROOT>/contracts/*.schema.json`
2. Load project context paths from setup config (and auto-context files when enabled).
3. Merge in optional task-level `TECH_CONTEXT` from runtime payload.
4. In `REAL_RUN`, enforce branch workflow before edits:
   - checkout base branch
   - `git pull -r`
   - create/switch to a working branch
5. Never implement directly on base branch.

## Run modes
- `REAL_RUN`: full execution, including code edits, validations, and changelog updates.
- `DRY_RUN`: simulate orchestration and planning checks without applying code edits.
- `PLAN_ONLY`: generate implementation plan, risks, touched-files forecast, `run_summary.md`, send `PLAN_ONLY_DONE`, and stop before any repository mutation.

## Mandatory preflight checks
- Fail if `JIRA_KEY` does not match configured Jira prefix.
- Fail if worktree is dirty in `REAL_RUN`.
- Fail if configured project context paths contain missing files.
- Fail if `WRITE_ARTIFACTS=true` and `ARTIFACTS_PATH` is missing or not writable.
- Fail if `NOTIFY_GOOGLE_CHAT=true` and webhook is missing/invalid.
- Fail if `integrations.jira_base_url` is missing or invalid.
- Fail if `FIGMA_NODE_IDS` is provided and `integrations.figma_base_url` is missing or invalid.
- Base branch special case:
  - If local base branch is missing but remote exists, continue (runner can fetch/track branch).
  - Fail only if branch is missing both locally and remotely.

## Preflight output modes
- `text` (default): human-readable console messages.
- `json`: single structured object with `status`, `code`, `field`, `message`, `warnings`.

## Orchestration order
0. For `PLAN_ONLY`, stop after planning artifacts, generate `run_summary.md`, send completion notification, and do not run implementation/command gating.
1. Run `jira-intake`
2. Run `figma-intake` when Figma fields are provided
3. Run `spec-filler`
4. Run `dev-executor`
5. Run local/relevant tests and QA gate checks
6. Update changelog from real code diff
7. Run `qa-retro`
8. Send Google Chat notifications per workflow policy

## Command gating
- `PLAN_ONLY` never enters command gating.
- Never auto-commit, auto-push, or auto-merge by default.
- After `READY_FOR_REVIEW`, wait for explicit user command:
  - `EFFECTIVIZE_COMMIT`
  - `CREATE_MR`
  - `EFFECTIVIZE_COMMIT_AND_CREATE_MR`

## Error policy
- Attempt autonomous retries and fixes first.
- Emit `ERROR_BLOCKING` only when retries are exhausted or blocked by external dependencies.

## Artifact policy
- By default, keep artifacts in memory and do not write inside target repo.
- Write artifact files only when `WRITE_ARTIFACTS=true` in setup config.
- If `WRITE_ARTIFACTS=true`, require configured `ARTIFACTS_PATH` to be writable.
- To change artifact behavior, rerun `playbook-setup` and update project config.

## Output expectations
- Keep user informed with concise progress updates.
- Keep outputs schema-compliant.
- Generate `run_summary.md` per run mode using `<PLAYBOOK_ROOT>/scripts/generate_run_summary.sh`:
  - `PLAN_ONLY`: at planning completion (before `PLAN_ONLY_DONE`).
  - `REAL_RUN`/`DRY_RUN`: at pipeline close.
- `run_summary.md` must adapt sections to `RUN_MODE` (`PLAN_ONLY` vs `REAL_RUN/DRY_RUN`).
