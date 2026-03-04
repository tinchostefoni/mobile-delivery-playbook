# Scripts Reference

This folder contains helper scripts used by the playbook skills and workflow.

## `install_skills.sh`
- Purpose: installs bundled skills into `$CODEX_HOME/skills`.
- Used by: repository bootstrap/update.
- Typical use:
```bash
bash scripts/install_skills.sh
```

## `bootstrap_playbook_setup.sh`
- Purpose: creates initial `.codex/playbook.config.yml` and optional auto-context files.
- Used by: `playbook-setup` when `SETUP_MODE=INIT`.
- Output:
  - `<REPO_ROOT>/.codex/playbook.config.yml`
  - `<REPO_ROOT>/.codex/project_context.auto.md` (when auto-detect is enabled)
  - `<REPO_ROOT>/.codex/project_context_paths.auto.txt` (when auto-detect is enabled)

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
  - `<REPO_ROOT>/.codex/pipeline-runner/<JIRA_KEY>/run_summary.md`
- Integration point:
  - `PLAN_ONLY`: generated when planning finishes.
  - `REAL_RUN`/`DRY_RUN`: generated at the end of execution with validations/blockers.

## `notify_google_chat.sh`
- Purpose: sends workflow status notifications to Google Chat incoming webhook.
- Used by: `pipeline-runner` when `NOTIFY_GOOGLE_CHAT=true`.
- Requires: `GOOGLE_CHAT_WEBHOOK_URL` — set as env var or in `<REPO_ROOT>/.env.playbook` (auto-loaded).

## `validate_playbook.sh`
- Purpose: validates this playbook repository consistency (skills, docs, scripts).
- Used by:
  - Local checks
  - Playbook CI (`.github/workflows/validate-playbook.yml`)
