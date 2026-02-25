# Skills to Contracts Map

## Agent order
1. `playbook-setup` -> writes `.codex/playbook.config.yml` (project defaults/context)
2. `jira-intake` -> outputs `ticket_spec`
3. `figma-intake` -> outputs `design_spec`
4. `spec-filler` -> outputs `implementation_brief`
5. `dev-executor` -> outputs `implementation_result`
6. `qa-retro` -> outputs `qa_result` (retrospective view)
7. `pipeline-runner` -> orchestrates the full sequence and emits notifications

## Stop vs continue
- Continue with assumptions when data is missing but non-critical.
- Stop when blocker affects acceptance criteria, security, or deployment safety.

## References
- Workflow: [workflow.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/workflow.md)
- Technical guide: [technical-reference.md](/Users/martinstefoni/Documents/Martín/mobile-delivery-playbook/technical-reference.md)
