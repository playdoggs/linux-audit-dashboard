# Running Tests

No automated test suite is currently in the repository.

## Baseline checks
```bash
python3 -m py_compile linux-security-dashboard.py
python3 linux-security-dashboard.py
```

## Manual regression checklist

### Security checks
- Verify `UFW` and `fail2ban` checks fail when `systemctl is-active` returns `inactive` and pass only on exact `active`.
- Verify `PermitRootLogin` and `PasswordAuthentication` checks ignore commented lines.

### Guided wizard
- Run SSH hardening wizard step and confirm `sed` commands apply correctly (shlex-parsed).
- Confirm multi-step fixes run sequentially — each command completes before the next starts.

### Actions and undo
- Run a remove/disable action and confirm undo entry is added.
- Roll back an action and confirm only the correct row is removed (two entries with the same timestamp must not collide).

### CVE / updates
- Online: CVE lookup populates rows and findings; terminal shows `[N/TOTAL] pkg — …` per package.
- Offline: CVE scan shows `⚠ Requires internet — CVE check skipped` in status label and terminal, and RUN EVERYTHING still completes.
- Switch from CVE scan to "Check for Available Updates" and confirm the CVE table clears (no stale rows).
- Updates offline: shows cached warning but still runs from local apt cache.

### Progress lines
- CVE, risky services, quick checks, and available updates all emit `[N/TOTAL]` prefixed lines in the terminal.
- Counter starts at 1 on each scan entry — no leftover counts from a previous run.

### Tool installs
- With no internet: clicking INSTALL on a tool card shows "Requires Internet" dialog and does not prompt for sudo.

### Theme / language / profile
- Switch theme and confirm persistent widgets update.
- Switch language and confirm persisted value.
- Re-open profile dialog and confirm selected profile affects NORMAL tagging.
