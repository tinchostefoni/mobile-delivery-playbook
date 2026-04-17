# Mobile Delivery Playbook

Operational playbook for mobile teams using Jira + Figma + GitLab with Claude skills.

## What you get
- Delivery standards for branch/commit/MR/changelog/quality gates.
- A canonical workflow (`playbook-setup` + `pipeline-runner`).
- Structured contracts (`JSON schemas`) for each pipeline stage.
- Reusable templates and scripts.
- Optional Google Chat notifications.

## Quick start

### Option A — Plugin (recommended)

Install once:
```bash
claude plugin marketplace add Gentleman-Programming/mobile-delivery-playbook
claude plugin install mobile-delivery-playbook
```

Done. Open any Cowork session and the pipeline skills are available immediately.

### Option B — Cowork with repo folder

Clone this repo and select the folder in Cowork. Claude reads `CLAUDE.md` automatically and the skills are available without any install step. Use this mode when developing the playbook itself.

---

Once installed (either option), run one-time project setup from chat:

```md
Use playbook-setup with this payload:
SETUP_MODE: INIT
REPO_PATH: /absolute/path/to/repo
PROJECT_NAME: <name>
JIRA_PROJECT_KEY: <e.g. LSF>
JIRA_BASE_URL: https://your-domain.atlassian.net
FIGMA_BASE_URL: https://www.figma.com/design/<fileKey>/<name>
ARCHITECTURE_OVERRIDE: Clean + Coordinator
TARGET_BASE_BRANCH: development
NOTIFY_GOOGLE_CHAT: true
AUTO_DETECT_CONTEXT: true
WRITE_ARTIFACTS: false
```

Then run per-ticket from chat:

```md
Use pipeline-runner with this payload:
JIRA_KEY: <ISSUE-ID>
FIGMA_NODE_IDS: 12:34,56:78
RUN_MODE: PLAN_ONLY
```

## Recommended run flow
1. `PLAN_ONLY`
2. Correct missing data and refine summary/context
3. `DRY_RUN`
4. If outputs look correct, execute `REAL_RUN`

## Main docs
- Workflow: [workflow.md](workflow.md)
- Standards: [mobile-gitlab-standard.md](mobile-gitlab-standard.md)
- Skills index: [skills/README.md](skills/README.md)
- Contracts: [contracts/README.md](contracts/README.md)
- Technical guide: [technical-reference.md](technical-reference.md)
- Scripts guide: [scripts/README.md](scripts/README.md)

## MCPs
- Required: Atlassian MCP, Figma MCP
- Optional: GitLab MCP (for MR creation — covered by `scripts/create_mr.sh` without MCP)
- Optional: Engram MCP (persistent memory across sessions — see below)
- Notifications: Google Chat incoming webhook via `GOOGLE_CHAT_WEBHOOK_URL`

Detailed setup and validation are in the technical guide.

## Persistent memory with Engram (optional but recommended)

Engram gives the pipeline persistent memory across sessions — architectural decisions, discovered patterns, bugfix root causes — so future runs are not starting from scratch.

**Install Engram** (once, on your machine):
```bash
# macOS/Linux via Homebrew
brew tap Gentleman-Programming/engram
brew install engram

# Or via plugin in Claude Code
claude plugin marketplace add Gentleman-Programming/engram
claude plugin install engram
```

**Register the MCP server** — already configured in `.claude/settings.json`:
```json
{
  "mcpServers": {
    "engram": { "command": "engram", "args": ["mcp"] }
  }
}
```

**Project isolation is automatic.** Engram auto-detects the project name from the git remote URL of the target repo. Memories are scoped per project — running the pipeline on `LSF` and `MAPP` in different sessions keeps their memories fully separate.

The Memory Protocol (when/how to save, session close, post-compaction recovery) is defined in `.claude/CLAUDE.md` and applied by `pipeline-runner` automatically when Engram MCP tools are available.

## Secrets setup (optional but recommended)

Copy the template to your project repo and fill in your credentials:

```bash
cp templates/.env.playbook.template /path/to/your/repo/.env.playbook
# then edit .env.playbook and fill in GITLAB_TOKEN and GOOGLE_CHAT_WEBHOOK_URL
```

The file is gitignored automatically by the playbook. Scripts load it without any extra configuration.

## Git operations (no MCP required)

All git operations work via Bash — no GitLab MCP needed:

- `EFFECTIVIZE_COMMIT` → runs `scripts/effectivize_commit.sh` (staged commit with conventional format)
- `CREATE_MR` → runs `scripts/create_mr.sh` (tries `glab` → GitLab API → manual URL fallback)
- Pipeline state is saved after each step and can be resumed if the session is interrupted

## Notes
- Generated runtime files stay in project `.playbook/` and are gitignored.
- Commit/push/merge are not automatic by default and require explicit chat commands.
- If a chat session is interrupted, say `resume pipeline <JIRA_KEY>` to pick up from the last completed step.
