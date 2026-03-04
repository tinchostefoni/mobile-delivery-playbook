# Mobile Delivery Playbook

Operational playbook for mobile teams using Jira + Figma + GitLab with Claude skills.

## What you get
- Delivery standards for branch/commit/MR/changelog/quality gates.
- A canonical workflow (`playbook-setup` + `pipeline-runner`).
- Structured contracts (`JSON schemas`) for each pipeline stage.
- Reusable templates and scripts.
- Optional Google Chat notifications.

## Quick start
1. Install bundled skills:

```bash
bash scripts/install_skills.sh
```

2. Run one-time project setup from chat:

```md
playbook-setup
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

3. Execute a run from chat:

```md
pipeline-runner
JIRA_KEY: <ISSUE-ID>
FIGMA_NODE_IDS: 12:34,56:78
RUN_MODE: REAL_RUN|DRY_RUN|PLAN_ONLY

TECH_CONTEXT: |
  Task-level technical notes and constraints.
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
- Notifications: Google Chat incoming webhook via `GOOGLE_CHAT_WEBHOOK_URL`

Detailed setup and validation are in the technical guide.

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
