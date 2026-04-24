# AGENT OPERATIONAL DIRECTIVES (CRITICAL)

## Documentation Authority
You are an agent with a Documentation-First mandate. Technical state must be mirrored in `agent_docs/`.

- Path: `./agent_docs/`
- Before changing code, read relevant docs in `agent_docs/`.
- After changing code, update corresponding docs.

## Specific File Mapping
- Builds: `agent_docs/building_the_project.md`
- Tests: `agent_docs/running_tests.md`
- Standards: `agent_docs/code_conventions.md`
- Logic/Flow: `agent_docs/service_architecture.md`
- Data: `agent_docs/database_schema.md`
- API/Events: `agent_docs/service_communication_patterns.md`
- Known Issues: `agent_docs/known_bugs.md`

---

# CLAUDE.md — AI Developer Context

## Project Summary
Linux Security Dashboard is a PyQt6 desktop app that audits Linux security posture in everyday language.

Core principles:
1. No system-changing action without explicit confirmation.
2. Show command intent clearly before execution.
3. Keep beginner-friendly explanations available for every finding.
4. Use background workers for slow operations.

## Tech Stack
- Python 3.10+
- PyQt6
- Single-file app (`linux-security-dashboard.py`)
- Optional Linux tools: `deborphan`, `lynis`

## Current Version
- v4.2

## Current Features (implemented)
- Scan modules: unused software, open ports, risky services
- Package inventory split: OS pre-installed vs user-installed (apt)
- Quick hardening checks
- Lynis audit integration
- CVE checks (Ubuntu API)
- Upgrade checks (`apt list --upgradable`)
- Guided fix wizard
- Tool manager cards with install/run/help
- Undo panel with persisted rollback log
- Risk score + face indicator
- Report generation (Executive/Technical HTML)
- Startup wizard + profile detection
- Theme lock + saved preferences

## Open Issues (as of 2026-04-23 review)
See `agent_docs/known_bugs.md` for full detail and line references.

## Session Guidelines for AI Assistants
1. Read docs first.
2. Prefer smallest safe change.
3. Keep UI-thread safety intact (workers emit signals; GUI updates in main thread only).
4. Update docs in same change set.
