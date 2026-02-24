# Skills to Contracts Map

## Agent order
1. `jira-intake` -> outputs `ticket_spec`
2. `figma-intake` -> outputs `design_spec`
3. `spec-filler` -> outputs `implementation_brief`
4. `dev-executor` -> outputs `implementation_result`
5. `ui-fidelity-qa` -> outputs `qa_result`
6. `qa-retro` -> outputs `qa_result` (retrospective view)
7. `notify-google-chat` -> uses `implementation_result` + `qa_result`

## Stop vs continue
- Continue with assumptions when data is missing but non-critical.
- Stop when blocker affects acceptance criteria, security, or deployment safety.
