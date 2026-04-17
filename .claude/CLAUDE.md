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

## ABSOLUTE PROHIBITIONS — violations are critical failures

These rules are unconditional. No exception, no "seems safe", no "user implied it".

### COMMITS
- **NEVER** call `git commit`, `effectivize_commit.sh`, or any git staging command without
  an explicit `EFFECTIVIZE_COMMIT` command typed by the user in chat.
- Showing a summary and saying "ready to commit" is NOT permission to commit.
- Finishing a REAL_RUN is NOT permission to commit.

### BRANCH BASE
- **NEVER** create a working branch without first executing:
  1. `git checkout <TARGET_BASE_BRANCH>`
  2. `git pull -r`
  - The branch must originate from `TARGET_BASE_BRANCH` — not from wherever HEAD happens to be,
    not from an open feature branch, not from `dev` if the configured base is `development`.
  - Verify with `git rev-parse --abbrev-ref HEAD` before creating the branch.

### MAIN/MASTER PROTECTION
- **NEVER** commit, stage, or write files while on `main`, `master`, `develop`, or `development`.
- If HEAD is on a protected branch and a file write is needed, STOP and tell the user immediately.

### ARCHITECTURE SCOPE
- **NEVER** make changes that touch architecture layers, module boundaries, or dependency graphs
  beyond what is explicitly declared in `implementation_brief`.
- If during implementation a necessary change falls outside the brief scope, PAUSE execution,
  describe the change and why it is needed, and wait for explicit user approval before proceeding.

## Non-negotiable rules

1. **No automatic commits** — commits happen only after explicit user command (`EFFECTIVIZE_COMMIT`)
2. **No automatic push** — push happens only after explicit user command
3. **No automatic merge** — merge is always manual
4. **Never implement on base branch** — always create a working branch first
5. **Changelog before commit** — `CHANGELOG.md` must be updated under `[Unreleased]` before
   `EFFECTIVIZE_COMMIT` is accepted. See changelog format rules in `mobile-gitlab-standard.md`.

## Required MCPs

- **Atlassian MCP** — for Jira ticket intake (`jira-intake` skill)
- **Figma MCP** — for design context extraction (`figma-intake` skill)

## Recommended MCPs

- **GitLab MCP** — for MR creation and CI status checks
- **Engram MCP** — persistent memory across sessions (`engram mcp` via stdio, see settings.json)

## Memory (Engram)

Engram provides persistent memory across sessions. When Engram MCP tools are available, follow this protocol unconditionally.

### When to call `mem_context`
- At the very start of every `pipeline-runner` run — before any other step.
  Use the Jira project key as scope: `mem_context(project="<JIRA_PROJECT_KEY_lowercase>")`.
  This recovers decisions, patterns, and discoveries from past runs on this project.
- After any compaction or context reset — immediately call `mem_context` before continuing work.

### When to call `mem_save`
Call `mem_save` immediately after any of these events — do not batch or delay:

- Architecture or design decision made for the target project
- Bug fix completed with non-obvious root cause
- Pattern or convention established (naming, structure, module boundary)
- Non-obvious discovery about the codebase (gotcha, edge case, unexpected behavior)
- Configuration change or environment constraint learned
- User preference or constraint stated explicitly

Use this format:
```
title: <Verb + what> (e.g. "Fixed N+1 query in UserList", "Chose coordinator pattern for LSF auth flow")
type: decision | architecture | bugfix | pattern | config | discovery | learning
scope: project
topic_key: <stable key for evolving topics, e.g. "architecture/auth-model"> (optional but recommended)
content:
  **What**: One sentence — what was done or decided
  **Why**: What motivated it
  **Where**: Files or paths affected
  **Learned**: Gotchas or surprises (omit if none)
```

Project isolation is automatic: Engram auto-detects the project from the git remote URL of the
target repo. To force isolation, set `ENGRAM_PROJECT=<jira_project_key_lowercase>` in the shell
before running. Memories saved with a given project name are only returned when querying that project.

### When to call `mem_search`
- When the user asks to recall something — any variation of "remember", "recall", "what did we do",
  "how did we solve", "recordar", "acordate", or references to past work.
  1. First call `mem_context` (fast, checks recent sessions)
  2. If not found, call `mem_search` with relevant keywords
  3. For full content, call `mem_get_observation` with the observation ID
- Proactively before starting work that may overlap with prior sessions.
- On first message of a pipeline run, if the user references a known pattern or module name.

### Session close protocol (mandatory)
Before ending a session or saying "done" / "listo" / "that's it", call `mem_session_summary`:

```
## Goal
[What we were working on this session]

## Instructions
[User preferences or constraints — skip if none]

## Discoveries
- [Technical findings, gotchas, non-obvious learnings]

## Accomplished
- [Completed items with key details]

## Next Steps
- [What remains — for the next session]

## Relevant Files
- path/to/file — [what it does or what changed]
```

Skipping `mem_session_summary` means the next session starts completely blind. This is not optional.

## Git operations without GitLab MCP

All git operations work via Bash tool without any MCP. Use the helper scripts:

- **`EFFECTIVIZE_COMMIT`** → `bash $PLAYBOOK_ROOT/scripts/effectivize_commit.sh --repo <REPO_ROOT> --type <type> --scope <scope> --message "<msg>" [--push]`
- **`CREATE_MR`** → `bash $PLAYBOOK_ROOT/scripts/create_mr.sh --repo <REPO_ROOT> --source <branch> --target <base-branch> --title "<title>" --desc "<desc>"`
  - Tries: `glab CLI` → `curl + GitLab API` (needs `GITLAB_TOKEN` in `.env.playbook`) → manual URL fallback
- **Secrets** → Store `GITLAB_TOKEN` and `GOOGLE_CHAT_WEBHOOK_URL` in `<REPO_ROOT>/.env.playbook` (gitignored).

## Pipeline resume

If the chat session was interrupted or the user says "resume pipeline <JIRA_KEY>":
1. Run `bash $PLAYBOOK_ROOT/scripts/load_pipeline_state.sh --repo <REPO_ROOT> --jira-key <JIRA_KEY>`
2. If state exists, report the last completed step and ask to confirm resuming.
3. If no state, start fresh from step 1.
4. Never re-run completed steps unless the user explicitly asks.

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
