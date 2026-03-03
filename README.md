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
- Recommended: GitLab MCP
- Notifications: Google Chat incoming webhook via `GOOGLE_CHAT_WEBHOOK_URL`

Detailed setup and validation are in the technical guide.

## Notes
- Generated runtime files should stay in project `.playbook/` and should be ignored in project `.gitignore`.
- Commit/push/merge are not automatic by default and require explicit chat commands.
