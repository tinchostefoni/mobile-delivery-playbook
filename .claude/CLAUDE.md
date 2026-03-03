# Mobile Delivery Playbook

This repository is an operational playbook for mobile (iOS) teams using Jira + Figma + GitLab.
It provides a structured pipeline that automates the flow from ticket intake to merge request.

## How to use

There are two main entry points — both are invoked from chat, not from the terminal:

### 1. `playbook-setup` (one-time per project)

Initializes project-level configuration. Run this first on any new target repository.

```
Use playbook-setup with this payload:
SETUP_MODE: INIT
REPO_PATH: /absolute/path/to/repo
PROJECT_NAME: <name>
JIRA_PROJECT_KEY: <e.g. LSF>
JIRA_BASE_URL: https://your-domain.atlassian.net
FIGMA_BASE_URL: https://www.figma.com/design/<fileKey>/<name>
TARGET_BASE_BRANCH: development
NOTIFY_GOOGLE_CHAT: true
AUTO_DETECT_CONTEXT: true
```

### 2. `pipeline-runner` (per ticket)

Executes the full pipeline for a single Jira ticket.

```
Use pipeline-runner with this payload:
JIRA_KEY: <ISSUE-ID>
FIGMA_NODE_IDS: 12:34,56:78
RUN_MODE: PLAN_ONLY
```

Recommended sequence: `PLAN_ONLY` → `DRY_RUN` → `REAL_RUN`.

## Key documentation

Read these files to understand the full system:

- **Workflow (canonical):** `workflow.md` — full execution sequence, run modes, notification policy
- **Standards:** `mobile-gitlab-standard.md` — commit, branch, MR, changelog, testing rules
- **Skills index:** `skills/README.md` — all available skills and install instructions
- **Contracts:** `contracts/README.md` — JSON schemas for inter-skill handoff
- **Technical reference:** `technical-reference.md` — implementation details, config model, preflight

## Non-negotiable rules

1. **No automatic commits** — commits happen only after explicit user command (`EFFECTIVIZE_COMMIT`)
2. **No automatic push** — push happens only after explicit user command
3. **No automatic merge** — merge is always manual
4. **Never implement on base branch** — always create a working branch first
5. **Changelog is mandatory** — every code change must be represented in `CHANGELOG.md` under `Unreleased`

## Required MCPs

- **Atlassian MCP** — for Jira ticket intake (`jira-intake` skill)
- **Figma MCP** — for design context extraction (`figma-intake` skill)

## Recommended MCPs

- **GitLab MCP** — for MR creation and CI status checks

## Auto-loading behavior

When starting a pipeline run, Claude must automatically:

1. **Resolve `PLAYBOOK_ROOT`** — if `scripts/preflight_pipeline_runner.sh` exists at the repo root,
   use that as playbook root (direct/Cowork mode). Otherwise look for the installed runtime at
   `~/.claude/skills/.mobile-delivery-playbook-runtime/`.
2. **Load `workflow.md`** — read it fully to understand the execution sequence for the current `RUN_MODE`.
3. **Load relevant contract schemas** from `contracts/*.schema.json` — use them to validate
   every inter-skill handoff artifact.
4. **Load `mobile-gitlab-standard.md`** — apply commit, branch, MR, and changelog standards.
5. **Load project config** from `<REPO_ROOT>/.playbook/playbook.config.yml` if it exists.
6. **Load auto-context** from `.playbook/project_context.auto.md` and `.playbook/project_context_paths.auto.txt` when enabled.

## Pre-run validation

Before executing any pipeline step, run the preflight validator:
```bash
bash $PLAYBOOK_ROOT/scripts/preflight_pipeline_runner.sh \
  --repo <REPO_ROOT> --base-branch <BRANCH> --jira-key <KEY> \
  --run-mode <MODE> --output-format json
```

If preflight fails, stop and report the failure to the user. Do not proceed with partial execution.

## Contract validation

After generating each contract artifact (ticket_spec, design_spec, implementation_brief,
implementation_result, qa_result), validate it against its schema:
```bash
bash $PLAYBOOK_ROOT/scripts/validate_contract.sh \
  --schema $PLAYBOOK_ROOT/contracts/<name>.schema.json \
  --data <artifact.json>
```

## Project configuration

When `playbook-setup` runs on a target project, it creates:
- `<REPO_ROOT>/.playbook/playbook.config.yml` — project configuration
- `<REPO_ROOT>/.playbook/project_context.auto.md` — auto-detected architecture context
- `<REPO_ROOT>/.playbook/project_context_paths.auto.txt` — key files for context loading

## Pipeline execution order

1. `jira-intake` → `ticket_spec`
2. `figma-intake` (if UI task) → `design_spec`
3. `spec-filler` → `implementation_brief`
4. `dev-executor` → code changes + `implementation_result`
5. Local tests + QA validation
6. `qa-retro` → `qa_result`
7. Notifications + user command gating
