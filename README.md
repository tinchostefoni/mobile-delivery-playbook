# Mobile Delivery Playbook

Operational playbook for mobile development teams using Jira + Figma + GitLab.

It includes:
- Global engineering standards for commits, branches, merge requests, changelog, and quality gates.
- A canonical workflow for agent-assisted delivery.
- Structured contracts (`JSON schemas`) to connect each pipeline step.
- Reusable templates for commit messages and merge requests.
- Google Chat notification integration.
- Recommended GitLab CI checks.

## Repository structure
- `mobile-gitlab-standard.md`: global standards (authoritative).
- `workflow.md`: canonical end-to-end workflow.
- `contracts/`: JSON schemas for `ticket_spec`, `design_spec`, `implementation_brief`, `implementation_result`, `qa_result`.
- `templates/`: commit and MR templates.
- `scripts/notify_google_chat.sh`: outbound notification script.
- `ci/recommended/`: recommended CI pipeline and validation scripts.

## Canonical run input
Use this payload when starting a run in Codex:

```md
@pipeline-runner
JIRA_KEY: <ISSUE-ID>
JIRA_URL: https://your-domain.atlassian.net/browse/<ISSUE-ID>
FIGMA_URL: https://www.figma.com/design/<fileKey>/<name>?node-id=<id>
FIGMA_NODE_IDS: 12:34,56:78
REPO_PATH: /absolute/path/to/repo
TARGET_BASE_BRANCH: dev|develop|development
NOTIFY_GOOGLE_CHAT: true
RUN_MODE: DRY_RUN
```

## Commit and MR policy highlights
- No automatic commit/push/merge by default.
- Commit/MR can be executed only by explicit chat command:
  - `EFFECTIVIZE_COMMIT`
  - `CREATE_MR`
  - `EFFECTIVIZE_COMMIT_AND_CREATE_MR`
- MR merge is always manual.
- Squash is mandatory.
- Minimum approvals: 1.

## Changelog policy
- Follow Keep a Changelog 1.1.0.
- Update `CHANGELOG.md` under `## [Unreleased]` for every code change.
- Entries must reflect real code diff and verified behavior, not Jira wording.
- Use past tense.
- Allowed sections: `Added`, `Changed`, `Fixed`, `Removed`, `Security`.

## Recommended CI setup
This repo provides a recommended GitLab CI configuration in:
- `ci/recommended/.gitlab-ci.recommended.yml`
- `ci/recommended/scripts/`

To adopt it in a project:
1. Copy the files into the target project.
2. Merge jobs into existing `.gitlab-ci.yml`.
3. Ensure merge settings in GitLab enforce green pipelines and approvals.

## Google Chat notifications
Configure webhook URL in environment:

```bash
export GOOGLE_CHAT_WEBHOOK_URL="<webhook-url>"
```

Example:

```bash
scripts/notify_google_chat.sh \
  "PROJECT-123" "READY_FOR_REVIEW" \
  "Local gates passed, waiting your command" \
  "https://your-domain.atlassian.net/browse/PROJECT-123"
```

## Notes
- Project-specific decisions (iOS matrix, simulator matrix, exact CI integration details) should be defined per repository.
