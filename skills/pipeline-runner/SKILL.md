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

PLAYBOOK_ROOT is resolved in this priority order:

1. **Direct/Cowork mode** — playbook repo folder is open as the selected directory:
   - Detect: `<REPO_ROOT>/scripts/preflight_pipeline_runner.sh` exists
   - `PLAYBOOK_ROOT` = `<REPO_ROOT>`

2. **Plugin mode** — plugin installed via `claude plugin install mobile-delivery-playbook`:
   - Detect: `<SKILL_DIR>/../../scripts/preflight_pipeline_runner.sh` exists
   - `PLAYBOOK_ROOT` = `<SKILL_DIR>/../..` (the plugin root)

3. **Legacy installed mode** — skills copied via `install_skills.sh`:
   - Detect: `<SKILL_DIR>/../.mobile-delivery-playbook-runtime/` exists
   - `PLAYBOOK_ROOT` = `<SKILL_DIR>/../.mobile-delivery-playbook-runtime/`

4. **Fail** — none of the above match:
   - Report: "Cannot resolve playbook runtime. Install the plugin or open the playbook repo in Cowork."

Use `$PLAYBOOK_ROOT` as prefix for all runtime references (scripts, contracts, templates).

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

## Blocking gates

Four gates are mandatory and sequential. Each one blocks the next step until it passes.
A gate failure must be reported to the user with a clear reason — pipeline does not continue.

### GATE 1 — Branch guard (REAL_RUN only, before any file change)
1. Run `git rev-parse --abbrev-ref HEAD` to confirm current branch.
2. If HEAD is `main`, `master`, `develop`, or `development`: STOP. Report error. Do not proceed.
3. If not on a working branch yet:
   a. `git checkout <TARGET_BASE_BRANCH>`
   b. `git pull -r`
   c. `git checkout -b <ISSUE-ID>-<kind>-<short-kebab-desc>`
4. Validate branch name: `<ISSUE-ID>-<kind>-<desc>`, no slash prefixes, no spaces.
5. Save branch name to pipeline state.
6. **BLOCK** if base branch is missing locally AND remotely, or if current branch is a protected branch.

### GATE 2 — Spec guard (after spec-filler, before dev-executor)
1. Launch `arch-reviewer` agent with the `implementation_brief` and project architecture context.
2. Wait for the agent's verdict.
3. If verdict is `BLOCK`:
   - Show the violations list to the user.
   - Wait for explicit user approval or brief correction before proceeding.
   - Do not run `dev-executor` until PASS or user explicitly overrides each BLOCK item.
4. If verdict is `PASS` or `WARN`: proceed immediately.
5. **BLOCK** dev-executor until gate passes.

### GATE 3 — Diff review (after dev-executor, before QA)
Launch `code-reviewer` and `naming-reviewer` agents in parallel on the diff. Both must pass.

**code-reviewer:**
1. Provide the full `git diff HEAD` output and the `implementation_brief`.
2. Wait for verdict.
3. If `BLOCK`: show blocking issues to user. Do not proceed to QA until resolved.
4. If `WARN`: show warnings, proceed to QA (issues tracked for next session).
5. If `PASS`: proceed.

**naming-reviewer:**
1. Provide the full `git diff HEAD` output.
2. Wait for verdict.
3. If `BLOCK`: show violations with suggested names. Do not proceed until fixed or user overrides.
4. If `WARN`: show warnings, proceed.
5. If `PASS`: proceed.

**Scope check (in addition to agents):**
- Run `git diff HEAD --name-only` and compare against `implementation_brief.files_forecast`.
- For any file NOT in the forecast: mark `[UNPLANNED]` and require a one-line justification.
- Unplanned files without justification: BLOCK.

**BLOCK** QA gate until both agents pass and all unplanned files are justified.

### GATE 4 — Pre-commit guard (when user issues EFFECTIVIZE_COMMIT)
1. Launch `commit-reviewer` agent with the proposed commit message and staged diff.
2. Wait for the agent's verdict.
3. If `BLOCK`: show exactly which check failed. Do not run `effectivize_commit.sh`. Wait for fix.
4. If `PASS`: run `effectivize_commit.sh` with the validated commit message.
5. **BLOCK** commit execution until `commit-reviewer` returns PASS.

## Orchestration order
0. **Memory recovery**: If Engram MCP is available, call `mem_context` filtered to this project
   before any other step — to recover past decisions, patterns, and discoveries.
   Then load saved pipeline state (resume check).
   For `PLAN_ONLY`, stop after planning artifacts, generate `run_summary.md`, send completion
   notification, and do not run implementation/command gating.
1. Run `jira-intake` → save state (`step=jira-intake`, `status=completed`)
2. Run `figma-intake` when Figma fields are provided → save state (`step=figma-intake`, `status=completed`)
3. Run `spec-filler` → save state (`step=spec-filler`, `status=completed`)
   - **mem_save**: Save the implementation approach as a `decision` with the spec summary
     (architecture choices, key constraints, affected modules) using `topic_key: "spec/<JIRA_KEY>"`.
4. ▶ **GATE 2 — Spec guard** (blocks step 5 until approved)
5. Run `dev-executor` → save state (`step=dev-executor`, `status=completed`)
   - **mem_save** after each non-obvious implementation decision, bugfix root cause, or discovered
     pattern — use `type: decision | bugfix | pattern | discovery` accordingly.
6. ▶ **GATE 3 — Diff review** (blocks step 7 until all unplanned changes are justified)
7. Run local/relevant tests and QA gate checks
   - **mem_save** any test failure root causes that were non-obvious, using `type: bugfix`.
8. Update `CHANGELOG.md` under `[Unreleased]` — must be done here, before command gating.
9. Run `qa-retro` → save state (`step=qa-retro`, `status=completed`)
10. Send Google Chat notifications per workflow policy
11. **Generate and print MR draft** before entering command gating (always, in REAL_RUN and DRY_RUN).
    Derive values from `ticket_spec`, `implementation_brief`, `qa_result`, and current branch:

    ```
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    MR DRAFT
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Title:
    [<JIRA_KEY>] <type>: <short explanation>

    Description:
    ### Summary
    <1–2 líneas del ticket_spec.summary>

    ### Changes
    - <key change from implementation_result>
    - <key change from implementation_result>

    ### Testing Steps
    1. <from qa_result.testing_steps or implementation_brief>
    2. <...>
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Source branch : <working-branch>
    Target branch : <TARGET_BASE_BRANCH>
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ```

    Rules for the MR title:
    - Format: `[<JIRA_KEY>] <type>: <short explanation>` (from `mobile-gitlab-standard.md` §3)
    - `type` reflects the dominant change of the MR (may differ from individual commit types)
    - Max 100 characters total
    - `[<JIRA_KEY>]` is mandatory in the MR title (distinct from commit format — no JIRA_KEY in commit)

    Store the draft in pipeline state so `CREATE_MR` can reuse it without re-generating.

12. Wait for user command (`EFFECTIVIZE_COMMIT` / `CREATE_MR` / `EFFECTIVIZE_COMMIT_AND_CREATE_MR`)
12. ▶ **GATE 4 — Pre-commit guard** (runs when EFFECTIVIZE_COMMIT is issued)
13. **Memory close**: At end of session (after user command or when saying "done"/"listo"),
    call `mem_session_summary` per protocol in `CLAUDE.md`. This is mandatory.

Note: **GATE 1** runs at the start of REAL_RUN, before step 1, as part of pre-run setup.

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
  --type        <conventional-type> \
  --scope       <module-scope>    \
  --message     "<short description>" \
  [--body       "<extended body>"] \
  [--push]
```
- Derives commit subject: `<type>(<scope>): <description>`
- Excludes `.env.playbook` and `.playbook/pipeline-runner/` from staging automatically.
- Add `--push` to push to origin in the same step.

### CREATE_MR execution (no Git MCP required)
Use the MR title and description pre-generated at step 11. Do not ask the user to supply them.
Run `$PLAYBOOK_ROOT/scripts/create_mr.sh` with:
```bash
bash $PLAYBOOK_ROOT/scripts/create_mr.sh \
  --repo    <REPO_ROOT>         \
  --source  <working-branch>    \
  --target  <target-base-branch> \
  --title   "<MR title from step 11 draft>" \
  --desc    "<MR description from step 11 draft>" \
  [--jira-key <JIRA_KEY>]       \
  [--remove-source-branch]
```
Strategy order: `glab CLI` → `curl + GitLab API (GITLAB_TOKEN)` → `manual URL fallback`.
Configure `GITLAB_TOKEN` in `.env.playbook` to enable automatic API-based MR creation.
Exit code 0 = MR created automatically. Exit code 1 = manual fallback package returned.
On fallback: display the pre-filled MR URL + title + description so the user can open it directly in the browser.

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
