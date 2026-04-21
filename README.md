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

Install once (two steps):
```bash
# 1. Add the marketplace
claude plugin marketplace add tinchostefoni/mobile-delivery-playbook

# 2. Install the plugin
claude plugin install mobile-delivery-playbook
```

Done. Open any Cowork session and the pipeline skills are available immediately.
Update when a new version is released:
```bash
claude plugin update mobile-delivery-playbook
```

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
- Bundled dependencies: [BUNDLED.md](BUNDLED.md)

## Required connectors

The pipeline needs Atlassian (Jira) and Figma connected to work. Both are built-in connectors in Claude Code and Cowork — no separate install needed.

**In Cowork**: open the Connectors section, find Atlassian and Figma, and authorize via OAuth. One-time per account.

**In Claude Code CLI**: add them once from the terminal:
```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/mcp
claude mcp add --transport http figma https://mcp.figma.com/mcp
```
Then authenticate each one with `/mcp` in Claude Code.

Other MCPs:
- **GitLab MCP**: optional — MR creation works without it via `scripts/create_mr.sh`
- **Engram MCP**: optional — adds persistent memory across sessions (see below)
- **Apple Docs MCP**: optional — Apple Developer Documentation + WWDC transcripts for arch/code review (see below)
- **XcodeBuildMCP**: optional — real builds, tests, coverage, screenshots and simulator control from within the pipeline (see below)
- **Google Chat**: notifications via `GOOGLE_CHAT_WEBHOOK_URL` in `.env.playbook`

Detailed setup in [technical-reference.md](technical-reference.md).

## Apple Docs MCP (optional — enhances arch and code review)

Gives `arch-reviewer` and `code-reviewer` access to the full Apple Developer Documentation and WWDC transcripts (2014–2025). No authentication required, zero setup beyond Node.js.

**No install needed.** The MCP server runs on demand via `npx`. Already configured in `.claude/settings.json`:
```json
{
  "mcpServers": {
    "apple-docs": { "command": "npx", "args": ["-y", "@kimsungwhee/apple-docs-mcp"] }
  }
}
```

When available, the review agents can verify API usage against official docs, look up deprecations, and check WWDC session guidance — without leaving the pipeline session.

Source: [kimsungwhee/apple-docs-mcp](https://github.com/kimsungwhee/apple-docs-mcp)

## XcodeBuildMCP (optional — enables real simulator QA)

Gives `dev-executor` and `qa-retro` direct access to your Xcode environment: compile the implementation, run the full test suite, get coverage reports, take screenshots, and capture the view hierarchy — all without leaving the pipeline session.

**No install needed.** The MCP server runs on demand via `npx`. Already configured in `.mcp.json`:
```json
{
  "mcpServers": {
    "xcode-build-mcp": { "command": "npx", "args": ["-y", "xcode-build-mcp"] }
  }
}
```

Requires macOS with Xcode installed. When available:
- **`dev-executor`** runs `build_sim` as a compilation gate — won't produce `implementation_result` if the build fails.
- **`qa-retro`** runs `build_sim` + `test_sim` + `get_coverage_report` + `screenshot` + `snapshot_ui` — merge gates are enforced against real results, not declared evidence.

The pipeline degrades gracefully when XcodeBuildMCP is unavailable: each skipped step is documented in the output artifacts.

Source: [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP)

## Persistent memory with Engram (optional — pipeline works without it)

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
