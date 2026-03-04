# Scripts Reference

This folder contains helper scripts used by the playbook skills and workflow.

## `install_skills.sh`
- Purpose: installs bundled skills into `~/.claude/skills`.
- Used by: repository bootstrap/update.
- Typical use:
```bash
bash scripts/install_skills.sh
```

## `bootstrap_playbook_setup.sh`
- Purpose: creates initial `.playbook/playbook.config.yml` and optional auto-context files.
- Used by: `playbook-setup` when `SETUP_MODE=INIT`.
- Output:
  - `<REPO_ROOT>/.playbook/playbook.config.yml`
  - `<REPO_ROOT>/.playbook/project_context.auto.md` (when auto-detect is enabled)
  - `<REPO_ROOT>/.playbook/project_context_paths.auto.txt` (when auto-detect is enabled)

## `update_playbook_setup.sh`
- Purpose: updates existing setup config.
- Used by: `playbook-setup` when `SETUP_MODE=UPDATE`.
- Behavior:
  - If `--repo` is omitted, uses `project.repo_path` previously saved by INIT config.
  - Fails if that saved repo path cannot be found.

## `preflight_pipeline_runner.sh`
- Purpose: validates required inputs and environment before pipeline execution.
- Used by: `playbook-setup` (setup preflight) and `pipeline-runner` (run preflight).
- Output modes:
  - `--output-format text`
  - `--output-format json`
- Blocks on invalid/missing critical configuration.

## `generate_run_summary.sh`
- Purpose: generates mode-aware `run_summary.md`.
- Used by: `pipeline-runner`.
- Default output:
  - `<REPO_ROOT>/.playbook/pipeline-runner/<JIRA_KEY>/run_summary.md`
- Integration point:
  - `PLAN_ONLY`: generated when planning finishes.
  - `REAL_RUN`/`DRY_RUN`: generated at the end of execution with validations/blockers.

## `notify_google_chat.sh`
- Purpose: sends workflow status notifications to Google Chat incoming webhook.
- Used by: `pipeline-runner` when `NOTIFY_GOOGLE_CHAT=true`.
- Requires:
  - `GOOGLE_CHAT_WEBHOOK_URL` env var.

## `validate_contract.sh`
- Purpose: validates a JSON artifact against its JSON Schema.
- Used by: all pipeline skills after generating contract artifacts.
- Requires: `python3` (uses `jsonschema` library when available, falls back to basic validation).
- Usage:
```bash
bash scripts/validate_contract.sh --schema contracts/ticket_spec.schema.json --data artifact.json
bash scripts/validate_contract.sh --schema contracts/ticket_spec.schema.json --data-stdin < artifact.json
```
- Output modes: `--output-format text` (default) or `--output-format json`.

## `validate_playbook.sh`
- Purpose: validates this playbook repository consistency (skills, docs, scripts).
- Used by:
  - Local checks
  - Playbook CI (`.github/workflows/validate-playbook.yml`)

## `create_mr.sh`
- Purpose: Creates a GitLab MR without requiring a GitLab MCP or browser interaction.
- Used by: `pipeline-runner` when user issues `CREATE_MR` command.
- Strategy (in order): `glab CLI` → `curl + GitLab REST API` → manual URL fallback.
- Requires: `GITLAB_TOKEN` in `.env.playbook` for API strategy. `glab` CLI for CLI strategy.
- Usage:
```bash
bash scripts/create_mr.sh \
  --repo /path/to/repo --source feature-branch --target development \
  --title "feat(auth): [LSF-123] add login" --desc "MR description"
```
- Exit codes: `0` = MR created automatically. `1` = manual fallback returned.

## `effectivize_commit.sh`
- Purpose: Stages and commits code changes following the playbook commit convention.
- Used by: `pipeline-runner` when user issues `EFFECTIVIZE_COMMIT`.
- Commit format: `<type>(<scope>): [<JIRA_KEY>] <description>`
- Excludes `.env.playbook` and `.playbook/pipeline-runner/` from staging automatically.
- Usage:
```bash
bash scripts/effectivize_commit.sh \
  --repo /path/to/repo --jira-key LSF-123 \
  --type feat --scope auth --message "add login validation" \
  [--push]
```

## `save_pipeline_state.sh`
- Purpose: Persists pipeline execution state to `.playbook/pipeline-runner/<JIRA_KEY>/pipeline_state.json`.
- Used by: `pipeline-runner` after each skill step to enable session resume.
- Usage:
```bash
bash scripts/save_pipeline_state.sh \
  --repo /path/to/repo --jira-key LSF-123 --run-mode REAL_RUN \
  --step jira-intake --status completed \
  --completed-steps jira-intake,figma-intake
```

## `load_pipeline_state.sh`
- Purpose: Loads saved pipeline state so an interrupted run can be resumed.
- Used by: `pipeline-runner` on resume command.
- Usage:
```bash
bash scripts/load_pipeline_state.sh --repo /path/to/repo --jira-key LSF-123
bash scripts/load_pipeline_state.sh --repo /path/to/repo --jira-key LSF-123 --output-format json
```
- Exit codes: `0` = state found. `1` = no state found.
