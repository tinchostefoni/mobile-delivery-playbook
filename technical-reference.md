# Technical Reference

This document contains implementation-level details for `playbook-setup` and `pipeline-runner`.

## 1) Configuration model

Project configuration is stored in:
- `<REPO_ROOT>/.playbook/playbook.config.yml`

Optional auto-context files:
- `<REPO_ROOT>/.playbook/project_context.auto.md`
- `<REPO_ROOT>/.playbook/project_context_paths.auto.txt`

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

Recommended run sequence:
1. `PLAN_ONLY`
2. Correct missing data/steps from summary/plan output
3. `DRY_RUN`
4. Run `REAL_RUN` once checks and scope look correct

For `DRY_RUN` and `REAL_RUN`, response quality bar:
1. List planned changes precisely (files/modules/behavior)
2. List non-changes explicitly
3. Provide diff vs prior plan output
4. Explain architecture alignment (or deviation)
5. Justify every unplanned change technically

## 3) Context precedence

Effective values are resolved in this order:
1. Runtime payload (only allowed runtime fields)
2. `<REPO_ROOT>/.playbook/playbook.config.yml`
3. Runner defaults

Context loading:
- Task-level context: `TECH_CONTEXT` from runtime payload.
- Project-level context: setup config + auto-context files under `.playbook/`.
- If `context.architecture_override` is set, architecture wording uses that value and does not rely on detector inference.

## 4) Branch safety behavior

For `REAL_RUN`, runner must execute:
1. checkout `TARGET_BASE_BRANCH`
2. `git pull -r`
3. create/switch to working branch

Implementation on base branch is not allowed.

## 5) Preflight behavior

Script:
- [scripts/preflight_pipeline_runner.sh](scripts/preflight_pipeline_runner.sh)

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
- [scripts/generate_run_summary.sh](scripts/generate_run_summary.sh)

Default output:
- `<REPO_ROOT>/.playbook/pipeline-runner/<JIRA_KEY>/run_summary.md`

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
  - Persist to `ARTIFACTS_PATH` (recommended `<REPO_ROOT>/.playbook/pipeline-runner`).

## 8) Notifications

Google Chat notifier script:
- [scripts/notify_google_chat.sh](scripts/notify_google_chat.sh)

Events:
- `ACTION_REQUIRED`
- `PLAN_ONLY_DONE`
- `READY_FOR_REVIEW`
- `CI_PENDING`
- `CI_FAILED`
- `ERROR_BLOCKING`
- `FINALIZED`

`ERROR_BLOCKING` should be sent only after autonomous retry/repair attempts are exhausted.

## 9) MR creation strategy

MR creation is handled by `scripts/create_mr.sh` in three ordered strategies (no GitLab MCP required):

**Strategy 1 — glab CLI** (if `glab` is installed and authenticated):
```bash
glab mr create --source-branch <source> --target-branch <target> --title <title> --description <desc> --yes
```

**Strategy 2 — GitLab REST API** (if `GITLAB_TOKEN` is set in `.env.playbook`):
```bash
POST $GITLAB_API_URL/projects/:encoded_project/merge_requests
Headers: PRIVATE-TOKEN: $GITLAB_TOKEN
Body: { source_branch, target_branch, title, description, remove_source_branch, squash }
```

**Strategy 3 — Manual fallback** (always available, exit code 1):
Returns a pre-filled package in chat:
- prefilled MR title
- prefilled MR description (from template)
- source/target branch values
- direct GitLab create-MR URL with pre-encoded query params
- concise reason for automatic creation failure

Script reference: [scripts/create_mr.sh](scripts/create_mr.sh)

## 10) Git helper scripts

All git operations work via Bash tool without any MCP.

### `effectivize_commit.sh`
Stages and commits code changes following the conventional commit convention:

```
<type>(<scope>): [<JIRA_KEY>] <description>
```

- Excludes `.env.playbook` and `.playbook/pipeline-runner/` from staging automatically.
- Accepts `--push` to push to origin in the same invocation.
- Script reference: [scripts/effectivize_commit.sh](scripts/effectivize_commit.sh)

### `create_mr.sh`
Creates a GitLab MR using the 3-strategy cascade described in section 9.
- Script reference: [scripts/create_mr.sh](scripts/create_mr.sh)

## 11) Pipeline state persistence

After each skill step, `pipeline-runner` saves execution state to disk so interrupted sessions can resume.

State file location:
```
<ARTIFACTS_PATH>/<JIRA_KEY>/pipeline_state.json
```

Default `ARTIFACTS_PATH`: `<REPO_ROOT>/.playbook/pipeline-runner`

State schema (version 1):
```json
{
  "schema_version": 1,
  "jira_key": "LSF-123",
  "run_mode": "REAL_RUN",
  "working_branch": "LSF-123-feat-login",
  "current_step": "dev-executor",
  "status": "completed",
  "completed_steps": ["jira-intake", "figma-intake", "spec-filler", "dev-executor"],
  "notes": "",
  "updated_at": "2026-03-04T12:00:00Z",
  "created_at": "2026-03-04T11:45:00Z",
  "history": [...]
}
```

Resume flow (triggered by `resume pipeline <JIRA_KEY>`):
1. Run `scripts/load_pipeline_state.sh --repo <REPO_ROOT> --jira-key <KEY> --output-format json`
2. If found: report last completed step and working branch, ask user to confirm resuming.
3. If not found: start fresh.

Scripts: [scripts/save_pipeline_state.sh](scripts/save_pipeline_state.sh), [scripts/load_pipeline_state.sh](scripts/load_pipeline_state.sh)

## 12) Secrets management (.env.playbook)

Sensitive values (tokens, webhook URLs) are stored separately from project config in a gitignored file.

File: `<REPO_ROOT>/.env.playbook` (gitignored, never committed)
Template: [templates/.env.playbook.template](templates/.env.playbook.template)

Available variables:
| Variable | Required for | Description |
|---|---|---|
| `GITLAB_TOKEN` | `create_mr.sh` API strategy | GitLab personal access token (api + write_repository scopes) |
| `GITLAB_API_URL` | `create_mr.sh` API strategy | Default: `https://gitlab.com/api/v4`. Override for self-hosted instances. |
| `GOOGLE_CHAT_WEBHOOK_URL` | `notify_google_chat.sh` | Google Chat incoming webhook URL |

All scripts that need these values auto-source `.env.playbook` if present. No extra configuration needed.

## 13) Persistent memory (Engram)

Engram provides cross-session persistent memory for the pipeline. It runs as an MCP server
and exposes 15 tools for saving, searching, and summarizing observations across sessions.

### Configuration

Engram MCP is pre-configured in `.claude/settings.json`:
```json
{
  "mcpServers": {
    "engram": { "command": "engram", "args": ["mcp"] }
  }
}
```

The binary must be installed separately on the host machine:
- macOS/Linux: `brew install engram` (after `brew tap Gentleman-Programming/engram`)
- Claude Code plugin: `claude plugin marketplace add Gentleman-Programming/engram && claude plugin install engram`

### Project isolation

Each target project gets its own isolated memory namespace automatically. Engram auto-detects
the project name from the git remote origin URL of the target repo (extracts the repo name).

Auto-detection priority chain:
1. `--project` flag on the `engram mcp` command
2. `ENGRAM_PROJECT` environment variable
3. Git remote origin URL (extracts repo name)
4. Git root directory name
5. Current working directory basename

To force explicit isolation, set `ENGRAM_PROJECT=<project_name>` in the shell environment.

### Key tools used by pipeline-runner

| Tool | When called |
|------|------------|
| `mem_context` | Start of every pipeline run — recovers past session state for this project |
| `mem_save` | After architecture decisions, bugfixes, discovered patterns, config changes |
| `mem_search` | When user asks to recall past work; proactively before overlapping tasks |
| `mem_get_observation` | Full content of a specific observation by ID |
| `mem_suggest_topic_key` | Before `mem_save` on evolving topics (e.g. architecture decisions) |
| `mem_session_summary` | Mandatory at session close or before saying "done" / "listo" |

### mem_save format

```
title: <Verb + what>
type: decision | architecture | bugfix | pattern | config | discovery | learning
scope: project
topic_key: <stable key for evolving topics> (optional)
content:
  **What**: One sentence — what was done or decided
  **Why**: What motivated it
  **Where**: Files or paths affected
  **Learned**: Gotchas or surprises (omit if none)
```

Full Memory Protocol is defined in `.claude/CLAUDE.md`.

### After compaction

If the context window is compacted (summarized to free space), the agent must:
1. Immediately call `mem_session_summary` with the compacted summary content
2. Then call `mem_context` to recover additional context from previous sessions
3. Only then continue working

This prevents losing all progress accumulated before the compaction.

## 14) Gentleman Guardian Angel (GGA)

GGA is an optional pre-commit hook that validates staged Swift files against project rules
before any commit is created. It is a complementary layer to Gate 4, not a replacement.

### Install (per target repo, one-time)

```bash
# macOS
brew install gentleman-programming/tap/gga

# Any platform
curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentleman-guardian-angel/main/install.sh | bash
```

Or run `playbook-setup` with `GGA_SETUP: true` to automate the full setup.

### Per-repo configuration

After `gga init`, edit `.gga` in the repo root:

```bash
PROVIDER="claude"
FILE_PATTERNS="*.swift"
EXCLUDE_PATTERNS="*Tests.swift,*Spec.swift,*Mock*.swift"
RULES_FILE="AGENTS.md"
```

`ANTHROPIC_API_KEY` must be set in the shell environment (or `.env.playbook` if sourced).

### AGENTS.md

The rules file GGA reads. A project-ready iOS/Swift template is at:
`$PLAYBOOK_ROOT/templates/AGENTS.md`

Copy it to your repo root and customize:
```bash
cp $PLAYBOOK_ROOT/templates/AGENTS.md <REPO_ROOT>/AGENTS.md
```

Never overwrite a project's existing `AGENTS.md` automatically.

### Hook commands

```bash
gga install          # Install pre-commit hook (appends to existing hook if present)
gga run              # Manual run on staged files (uses cache)
gga run --no-cache   # Manual run, ignore cache
gga uninstall        # Remove hook
```

### How it fits in the pipeline

```
git commit
  └─► GGA pre-commit hook
        ├─ Reads staged *.swift files
        ├─ Reads AGENTS.md rules
        ├─ Sends to Claude → STATUS: PASSED / STATUS: FAILED
        └─ FAILED → commit blocked; user fixes code and retries
             ↓
        Commit created
             ↓
  EFFECTIVIZE_COMMIT (user command)
        └─► Gate 4 (commit-reviewer agent)
              ├─ Protected branch check
              ├─ Staged file safety (secrets)
              ├─ Changelog presence
              ├─ Commit message format
              └─ Diff scope alignment
```

### Layer responsibilities

| Layer | Scope | Runs when |
|-------|-------|-----------|
| **GGA** | Swift code quality (memory, force unwrap, naming, arch) | Every `git commit` |
| **Gate 4** | Workflow compliance (message format, changelog, branch, secrets) | `EFFECTIVIZE_COMMIT` command |

GGA is git-native and runs independently of the pipeline agent. Gate 4 is agent-driven and
enforces playbook-level rules that GGA does not cover.

## 15) Apple Docs MCP (optional)

Provides `arch-reviewer` and `code-reviewer` with direct access to Apple Developer Documentation and WWDC session transcripts (2014–2025). No authentication required.

### Setup

No install needed — the server runs on demand via `npx`. Add to `.claude/settings.json` (already included in this repo):

```json
"apple-docs": {
  "command": "npx",
  "args": ["-y", "@kimsungwhee/apple-docs-mcp"]
}
```

For Claude Code CLI, register it once:
```bash
claude mcp add apple-docs -- npx -y @kimsungwhee/apple-docs-mcp
```

### Available tools (15 total)

| Tool | Description |
|------|-------------|
| `search_apple_documentation` | Full-text search across Apple docs |
| `get_documentation` | Fetch a specific doc page by URL |
| `get_wwdc_sessions` | List WWDC sessions by year/topic |
| `search_wwdc_sessions` | Search WWDC transcripts by keyword |
| `get_wwdc_transcript` | Fetch full transcript of a WWDC session |
| `get_technologies` | List all documented Apple frameworks |
| + 9 more | (deprecations, related docs, sample code, etc.) |

### How it fits in the pipeline

`arch-reviewer` and `code-reviewer` agents can call these tools automatically when the MCP is available:

- **arch-reviewer (Gate 2)**: Verify that proposed APIs exist and are not deprecated. Check framework availability by OS version.
- **code-reviewer (Gate 3)**: Validate API usage against official docs. Cross-reference WWDC guidance on concurrency, memory, or SwiftUI patterns.

The pipeline degrades gracefully — if the MCP is not running, agents continue without it.

Source: [kimsungwhee/apple-docs-mcp](https://github.com/kimsungwhee/apple-docs-mcp)


## 16) XcodeBuildMCP — expanded usage

XcodeBuildMCP communicates with the user's macOS Xcode environment via MCP protocol, allowing the pipeline to run real builds, tests, screenshots, and simulator actions directly from within the agent session.

### Pipeline integration

| Stage | Tools used | Purpose |
|-------|-----------|---------|
| **dev-executor** (after implementation) | `session_show_defaults`, `discover_projs`, `build_sim` | Compilation gate — confirm the implementation compiles before producing `implementation_result` |
| **qa-retro** (Gate 5) | `session_show_defaults`, `boot_sim`, `build_sim`, `test_sim`, `get_coverage_report`, `launch_app_logs_sim`, `screenshot`, `snapshot_ui` | Real QA evidence — green build, test pass/fail, coverage %, launch logs, visual screenshot, view hierarchy |

### Session defaults

Before running any build or test tool, confirm the project is configured:

```
session_show_defaults()  →  shows current projectPath/workspacePath, scheme, simulator
session_set_defaults(workspacePath, scheme, simulatorName)  →  set once per session
```

If defaults are missing, run `discover_projs(workspaceRoot: <REPO_PATH>)` to find `.xcworkspace` / `.xcodeproj` files, then call `session_set_defaults`.

### Tool reference

| Tool | Key parameters | Returns |
|------|---------------|---------|
| `discover_projs` | `workspaceRoot`, `maxDepth?` | List of project/workspace paths |
| `session_show_defaults` | — | Current scheme, simulator, project path |
| `session_set_defaults` | `workspacePath\|projectPath`, `scheme`, `simulatorName` | Confirmation |
| `boot_sim` | — | Boots the configured simulator |
| `build_sim` | `extraArgs?` | Build output + error log |
| `test_sim` | `extraArgs?`, `testRunnerEnv?` | Test results + xcresult path |
| `get_coverage_report` | `xcresultPath`, `showFiles?`, `target?` | Coverage % summary |
| `get_file_coverage` | `xcresultPath`, `file`, `showLines?` | Per-file line coverage |
| `launch_app_logs_sim` | `args?`, `env?` | App launch + startup log output |
| `screenshot` | `returnFormat?` | Screen capture (base64 or file) |
| `snapshot_ui` | — | Accessibility/view hierarchy snapshot |

### Graceful degradation

If XcodeBuildMCP tools are unavailable (e.g., user is not on macOS or Xcode is not installed):
- `dev-executor`: document skipped in `implementation_result.validations`
- `qa-retro`: set `all_tests_green: false` unless the user provides CI green evidence from another source; document each skipped step in `qa_result.validations`
