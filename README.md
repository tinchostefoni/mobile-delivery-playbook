# Mobile Delivery Playbook

Operational playbook for mobile teams using Jira + Figma + GitLab with Codex skills.

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

## Main docs
- Workflow: [workflow.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/workflow.md)
- Standards: [mobile-gitlab-standard.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/mobile-gitlab-standard.md)
- Skills index: [skills/README.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/skills/README.md)
- Contracts: [contracts/README.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/contracts/README.md)
- Technical guide: [technical-reference.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/technical-reference.md)
- Scripts guide: [scripts/README.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/scripts/README.md)

## MCPs
- Required: Atlassian MCP, Figma MCP
- Recommended: GitLab MCP
- Notifications: Google Chat incoming webhook via `GOOGLE_CHAT_WEBHOOK_URL`

Detailed setup and validation are in the technical guide.

## Notes
- Generated runtime files should stay in project `.codex/` and should be ignored in project `.gitignore`.
- Commit/push/merge are not automatic by default and require explicit chat commands.
