# Known Bugs and Security Concerns

Audit date: **2026-04-23**

## Open
None currently tracked. File an issue as a new `### N) ...` block if one surfaces.

## Recently resolved (regression guards)

### Quick-check false positives
- SSH checks now use anchored regex (`^\s*PermitRootLogin\s+(no|prohibit-password)\b` and `^\s*PasswordAuthentication\s+no\b`) — commented/unrelated lines no longer pass.
- UFW and fail2ban checks use exact equality (`o.strip() == "active"`) — "inactive" output no longer matches.
- Regression guard: do not reintroduce substring matching (`"active" in o.lower()`, `"no" in o.lower()`).

### Guided Wizard quoting
- Wizard parses string commands with `shlex.split()` and accepts pre-split lists for complex shell syntax.
- Regression guard: never use `cmd.split()` on user-facing fix commands.

### Guided Wizard step ordering
- Multi-step fixes run sequentially via `_run_next_fix_cmd()` draining a queue.
- Regression guard: no `for cmd in ...: CommandWorker(...).start()` loops.

### Undo row removal
- `_remove_undo_entry_after_rollback` matches on `time + action + cmd + undo_cmd` (four fields), not just `time`.
- Regression guard: keep all four fields in the match.

### Other previously addressed
- Background sudo prompts use `sudo -S` with `stdin=DEVNULL` fallback.
- Worker completion signaling avoids stuck "please wait" states.
- HTML report content is escaped via `html.escape()`.
- CVE HTTP calls use a TLS context and bounded retries.
- `CvePanel` is shared between CVE scan and Updates scan — both entry points clear `cve_table` on start.
- Internet-dependent features (CVE scan, tool install) gate on `has_internet()` and advise the user when offline instead of hanging on urllib timeouts.
