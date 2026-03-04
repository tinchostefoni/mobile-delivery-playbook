---
name: pipeline-runner
description: >
  Orchestrate the Jira+Figma mobile delivery pipeline end-to-end from a single payload block.
  Triggers when the user mentions pipeline-runner, wants to run implementation for a Jira ticket,
  or provides a payload with JIRA_KEY and RUN_MODE.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "JIRA_KEY: <KEY> FIGMA_NODE_IDS: <ids> RUN_MODE: PLAN_ONLY|DRY_RUN|REAL_RUN"
---

# Pipeline Runner

Use this skill when the user wants to run the canonical pipeline from a single message.

## Trigger phrase
- Recommended invocation: plain text (`Use pipeline-runner with this payload:`)
- Also triggers on `/pipeline-runner` when available as a slash command

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
- `RUN_SUMMARY_PATH`: `<REPO_ROOT>/.playbook/pipeline-runner/<JIRA_KEY>/run_summary.md`

## Playbook root resolution

The playbook runtime (scripts, contracts, workflow, templates) can live in two locations depending on context:

1. **Direct repo mode** (Cowork / working inside the playbook repo):
   - `PLAYBOOK_ROOT` = git root of the playbook repo itself.
   - Scripts at `$PLAYBOOK_ROOT/scripts/`, contracts at `$PLAYBOOK_ROOT/contracts/`, etc.
   - Detect: `$REPO_ROOT/skills/pipeline-runner/SKILL.md` exists → you are inside the playbook repo.

2. **Installed mode** (Claude Code CLI / skills installed to `~/.claude/skills/`):
   - `PLAYBOOK_ROOT` = `../.mobile-delivery-playbook-runtime/` relative to this skill file.
   - Scripts at `$PLAYBOOK_ROOT/scripts/`, contracts at `$PLAYBOOK_ROOT/contracts/`, etc.
   - Detect: this skill is at `~/.claude/skills/pipeline-runner/SKILL.md`.

Resolution algorithm:
```
if <REPO_ROOT>/scripts/preflight_pipeline_runner.sh exists:
  PLAYBOOK_ROOT = <REPO_ROOT>
else if <SKILL_DIR>/../.mobile-delivery-playbook-runtime/ exists:
  PLAYBOOK_ROOT = <SKILL_DIR>/../.mobile-delivery-playbook-runtime/
else:
  FAIL: "Cannot resolve playbook runtime. Run install_skills.sh or work from the playbook repo."
```

Use `$PLAYBOOK_ROOT` as prefix for all runtime references below.

## Config resolution
1. Resolve `REPO_ROOT` from current working directory (`git rev-parse --show-toplevel`).
2. Auto-load `<REPO_ROOT>/.playbook/playbook.config.yml`.
3. If config is missing, fail with explicit message: run `playbook-setup` first.
4. If available, read additional auto-context files:
   - `<REPO_ROOT>/.playbook/project_context.auto.md`
   - `<REPO_ROOT>/.playbook/project_context_paths.auto.txt`
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
   - `$PLAYBOOK_ROOT/scripts/preflight_pipeline_runner.sh`
   - Use `--output-format json` when machine-readable diagnostics are needed.
1. Load canonical workflow and contracts from playbook:
   - `$PLAYBOOK_ROOT/workflow.md`
   - `$PLAYBOOK_ROOT/contracts/*.schema.json`
2. Validate all contract outputs against their JSON schemas using `$PLAYBOOK_ROOT/scripts/validate_contract.sh`.
3. Load project context paths from setup config (and auto-context files when enabled).
4. Merge in optional task-level `TECH_CONTEXT` from runtime payload.
5. In `REAL_RUN`, enforce branch workflow before edits:
   - checkout base branch
   - `git pull -r`
   - create/switch to a working branch using the exact format from `mobile-gitlab-standard.md`:
     `<ISSUE-ID>-<kind>-<short-kebab-description>`
     Examples: `LSF-705-fix-avatar-refactor`, `LSF-123-feature-login-flow`
     **No slash prefixes** (`codex/`, `feature/`, `fix/`, etc.) — the ISSUE-ID is the only prefix.
6. Never implement directly on base branch.

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
1. Run `jira-intake` → save state (`step=jira-intake`, `status=completed`)
2. Run `figma-intake` when Figma fields are provided → save state (`step=figma-intake`, `status=completed`)
3. Run `spec-filler` → save state (`step=spec-filler`, `status=completed`)
4. Run `dev-executor` → save state (`step=dev-executor`, `status=completed`)
5. Run local/relevant tests and QA gate checks
6. Update changelog from real code diff
7. Run `qa-retro` → save state (`step=qa-retro`, `status=completed`)
8. Send Google Chat notifications per workflow policy

Save state after each step using:
```bash
bash $PLAYBOOK_ROOT/scripts/save_pipeline_state.sh \
  --repo <REPO_ROOT> --jira-key <JIRA_KEY> --run-mode <RUN_MODE> \
  --step <step-name> --status completed \
  --working-branch <branch> \
  --completed-steps <comma-separated-list>
```

## Pipeline resume
If the user says "resume pipeline <JIRA_KEY>" or the session was interrupted:
1. Load saved state: `bash $PLAYBOOK_ROOT/scripts/load_pipeline_state.sh --repo <REPO_ROOT> --jira-key <JIRA_KEY> --output-format json`
2. If state found: report the last completed step and current working branch, then ask the user to confirm resuming from the next step.
3. If state not found: start fresh from step 1.
4. Never re-run already-completed steps unless the user explicitly requests it.

## Command gating
- `PLAN_ONLY` never enters command gating.
- Never auto-commit, auto-push, or auto-merge by default.
- After `READY_FOR_REVIEW`, wait for explicit user command:
  - `EFFECTIVIZE_COMMIT`
  - `CREATE_MR`
  - `EFFECTIVIZE_COMMIT_AND_CREATE_MR`

### EFFECTIVIZE_COMMIT execution (no Git MCP required)
Run `$PLAYBOOK_ROOT/scripts/effectivize_commit.sh` with the following parameters:
```bash
bash $PLAYBOOK_ROOT/scripts/effectivize_commit.sh \
  --repo        <REPO_ROOT>       \
  --jira-key    <JIRA_KEY>        \
  --type        <conventional-type> \
  --scope       <module-scope>    \
  --message     "<short description>" \
  [--body       "<extended body>"] \
  [--push]
```
- Derives commit subject: `<type>(<scope>): [<JIRA_KEY>] <description>`
- Excludes `.env.playbook` and `.playbook/pipeline-runner/` from staging automatically.
- Add `--push` to push to origin in the same step.

### CREATE_MR execution (no Git MCP required)
Run `$PLAYBOOK_ROOT/scripts/create_mr.sh` with:
```bash
bash $PLAYBOOK_ROOT/scripts/create_mr.sh \
  --repo    <REPO_ROOT>         \
  --source  <working-branch>    \
  --target  <target-base-branch> \
  --title   "<MR title>"        \
  --desc    "<MR description>"  \
  [--jira-key <JIRA_KEY>]       \
  [--remove-source-branch]
```
Strategy order: `glab CLI` → `curl + GitLab API (GITLAB_TOKEN)` → `manual URL fallback`.
Configure `GITLAB_TOKEN` in `.env.playbook` to enable automatic API-based MR creation.
Exit code 0 = MR created automatically. Exit code 1 = manual fallback package returned.

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
- Generate `run_summary.md` per run mode using `$PLAYBOOK_ROOT/scripts/generate_run_summary.sh`:
  - `PLAN_ONLY`: at planning completion (before `PLAN_ONLY_DONE`).
  - `REAL_RUN`/`DRY_RUN`: at pipeline close.
- `run_summary.md` must adapt sections to `RUN_MODE` (`PLAN_ONLY` vs `REAL_RUN/DRY_RUN`).
- In every run response (`PLAN_ONLY`, `DRY_RUN`, `REAL_RUN`), include a clear `Recommended next step`.
- For `DRY_RUN` and `REAL_RUN`, include a technical change contract in the response:
  - `Planned changes` (exact files/modules and expected behavior changes)
  - `Non-changes` (what will NOT be touched)
  - `Plan diff` (what differs vs PLAN_ONLY/DRY_RUN plan)
  - `Architecture impact` (how changes align with intended architecture; flag deviations explicitly)
  - `Unplanned changes rationale` (mandatory when touching anything not declared in plan)
