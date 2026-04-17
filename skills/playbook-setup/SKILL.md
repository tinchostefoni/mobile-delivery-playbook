---
name: playbook-setup
description: >
  Initialize or update per-project pipeline defaults (.playbook/playbook.config.yml)
  including base branch, Jira prefix, Figma URL, tech context, and project context paths.
  Triggers when the user mentions playbook-setup, wants to configure a new project for the pipeline,
  or provides a payload with SETUP_MODE.
allowed-tools: Bash, Read, Write, Glob, Grep
argument-hint: "SETUP_MODE: INIT REPO_PATH: /path/to/repo PROJECT_NAME: <name>"
---

# Playbook Setup

Use this skill to create or update project-level configuration consumed by `pipeline-runner`.

## UX policy (chat-first)
- The user should only provide a payload in chat.
- Do not require terminal commands from the user.
- Internally, run `$PLAYBOOK_ROOT/scripts/bootstrap_playbook_setup.sh` (or equivalent logic) to auto-detect context and generate setup files.
- Immediately after setup, run `$PLAYBOOK_ROOT/scripts/preflight_pipeline_runner.sh --mode setup ...` and fail if validation fails.
- Always return generated file paths and the next `pipeline-runner` payload.

## Playbook root resolution

Same priority order as `pipeline-runner`:
1. Direct/Cowork: `<REPO_ROOT>/scripts/preflight_pipeline_runner.sh` exists → `PLAYBOOK_ROOT = <REPO_ROOT>`
2. Plugin mode: `<SKILL_DIR>/../../scripts/preflight_pipeline_runner.sh` exists → `PLAYBOOK_ROOT = <SKILL_DIR>/../..`
3. Legacy: `<SKILL_DIR>/../.mobile-delivery-playbook-runtime/` exists → `PLAYBOOK_ROOT = <SKILL_DIR>/../.mobile-delivery-playbook-runtime/`
4. Fail: "Cannot resolve playbook runtime. Install the plugin or open the playbook repo in Cowork."

## Trigger phrase
- Recommended invocation: plain text (`Use playbook-setup with this payload:`)
- Also triggers on `/playbook-setup` when available as a slash command

## Expected input block

```md
SETUP_MODE: INIT|UPDATE
REPO_PATH: <absolute path>
PROJECT_NAME: <human readable name>
JIRA_PROJECT_KEY: <e.g. LSF>
JIRA_BASE_URL: <required, https://your-domain.atlassian.net>
FIGMA_BASE_URL: <optional, https://www.figma.com/design/<fileKey>/<name>>
ARCHITECTURE_OVERRIDE: <optional, e.g. Clean + Coordinator>
TARGET_BASE_BRANCH: <dev|develop|development>
NOTIFY_GOOGLE_CHAT: <true|false>
AUTO_DETECT_CONTEXT: <true|false>

# optional, strongly recommended
TECH_CONTEXT: |
  Architecture notes, module boundaries, backend constraints.
PROJECT_CONTEXT_PATHS: docs/architecture.md,README.md,Sources/App/CompositionRoot.swift

# optional behavior defaults for pipeline-runner
WRITE_ARTIFACTS: false
# only when WRITE_ARTIFACTS=true
ARTIFACTS_PATH: <REPO_PATH>/.playbook/pipeline-runner

# optional: install Gentleman Guardian Angel pre-commit hook
GGA_SETUP: false
```

Mode behavior:
- `INIT`: full bootstrap (autodetect + config generation).
- `UPDATE`: update only configured global values (URLs, branch, notify, artifact flags, project key/name) without re-running bootstrap context generation.
- `UPDATE`: `REPO_PATH` is optional; if omitted, use the `repo_path` saved by `INIT` in `.playbook/playbook.config.yml`.

## Output file (created/updated)
- `<REPO_PATH>/.playbook/playbook.config.yml`
- `<REPO_PATH>/.playbook/project_context.auto.md` (only when `AUTO_DETECT_CONTEXT=true`)
- `<REPO_PATH>/.playbook/project_context_paths.auto.txt` (only when `AUTO_DETECT_CONTEXT=true`)

## Rules
1. Validate `REPO_PATH` exists and is a git repository (`UPDATE` may omit it and use `project.repo_path` saved by `INIT`).
2. Validate `TARGET_BASE_BRANCH` exists locally or remotely.
3. Validate `JIRA_BASE_URL` format (required) and `FIGMA_BASE_URL` format (optional).
4. `SETUP_MODE` defaults to `INIT`.
5. If `SETUP_MODE=UPDATE`, run `$PLAYBOOK_ROOT/scripts/update_playbook_setup.sh` and preserve existing `context.*` values.
6. `AUTO_DETECT_CONTEXT` defaults to `true`.
7. If `AUTO_DETECT_CONTEXT=true`, auto-detect project context and write:
   - `.playbook/project_context.auto.md`
   - `.playbook/project_context_paths.auto.txt`
8. If `ARCHITECTURE_OVERRIDE` is provided, use it as architecture source of truth and treat detector output as fallback.
9. If `AUTO_DETECT_CONTEXT=false`, do not overwrite auto-detected context files.
10. Write/update `.playbook/playbook.config.yml` with:
   - `project.name`
   - `project.repo_path`
   - `project.jira_project_key`
   - `integrations.jira_base_url`
   - `integrations.figma_base_url`
   - `pipeline.target_base_branch`
   - `pipeline.notify_google_chat`
   - `pipeline.auto_detect_context`
   - `pipeline.write_artifacts`
   - `pipeline.artifacts_path` only when `WRITE_ARTIFACTS=true`
   - `context.architecture_override` when provided
   - `context.tech_context`
   - `context.project_context_paths`
11. Keep values explicit and human-editable.
12. Preserve existing keys not provided by the user.
13. Run preflight in setup mode right after writing config/update.
14. After successful preflight, return a ready-to-run `pipeline-runner` payload.

## Recommended generated config shape

```yaml
version: 1
project:
  name: "Stop Apuestas Minor"
  repo_path: "/absolute/path/to/repo"
  jira_project_key: "LSF"
integrations:
  jira_base_url: "https://zafirus.atlassian.net"
  figma_base_url: "https://www.figma.com/design/FILE_KEY/Stop-Apuestas"
pipeline:
  target_base_branch: "development"
  notify_google_chat: true
  auto_detect_context: true
  write_artifacts: false
  artifacts_path: "/absolute/path/to/repo/.playbook/pipeline-runner"
context:
  architecture_override: "Clean + Coordinator"
  tech_context: |
    iOS app using Coordinator + MVVM with NotificationManager-driven remote actions.
  project_context_paths:
    - "README.md"
    - "docs/architecture.md"
```

## Optional: GGA setup

If `GGA_SETUP: true` is included in the payload, run the following after config is written:

1. **Check installation**: Run `which gga` or `gga --version`.
   - If not installed, print install instructions and skip remaining steps:
     ```
     GGA not found. Install with:
       brew install gentleman-programming/tap/gga    # macOS
       curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentleman-guardian-angel/main/install.sh | bash
     Then re-run playbook-setup with GGA_SETUP: true.
     ```
2. **Copy AGENTS.md template**: Copy `$PLAYBOOK_ROOT/templates/AGENTS.md` to `<REPO_PATH>/AGENTS.md`
   only if `AGENTS.md` does not already exist. Never overwrite an existing one.
3. **Initialize GGA config**: Run `gga init` in `<REPO_PATH>` to generate `.gga` if it doesn't exist.
   Then update `.gga` to set:
   - `PROVIDER="claude"`
   - `FILE_PATTERNS="*.swift"`
   - `EXCLUDE_PATTERNS="*Tests.swift,*Spec.swift,*Mock*.swift"`
   - `RULES_FILE="AGENTS.md"`
4. **Install the hook**: Run `gga install` in `<REPO_PATH>`.
5. **Report**: Print which files were created/updated and confirm the hook is active.

GGA relationship with Gate 4:
- **GGA** runs at the git level on every `git commit` — validates Swift code quality
  against `AGENTS.md` rules before the commit is created.
- **Gate 4 (commit-reviewer)** runs when the user issues `EFFECTIVIZE_COMMIT` — validates
  commit message format, changelog presence, branch safety, and staged file secrets.
- They are complementary layers: GGA catches code quality, Gate 4 catches workflow compliance.

## Handoff to pipeline-runner
Return this starter payload after setup:

```md
Use pipeline-runner with this payload:
JIRA_KEY: <LSF-123>
FIGMA_NODE_IDS: <12:34,56:78 or empty>
RUN_MODE: REAL_RUN

# optional, task-specific context
TECH_CONTEXT: |
  Task-level technical notes, constraints, backend contracts.
```
