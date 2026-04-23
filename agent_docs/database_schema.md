# Data Persistence Model

No SQL database is used.

## Persistent files

### `~/.audit-dashboard.conf` (INI)
Atomic writes via temp-file replace in `save_config()`. Stores:
- language
- profile
- theme lock state and locked theme
- sidebar collapse state keys (when written)

### `~/.audit-dashboard-undo.log` (JSONL)
One JSON object per action, with fields:
- `time`, `action`, `cmd`, `undo_cmd`
- `risk_level`
- rollback explanation fields (`rollback_risk`, `rollback_exploit`, …)
- `name`

Row deletion on successful rollback matches on `time + action + cmd + undo_cmd` (not just `time`) to avoid same-second collisions.

### Error log
- Preferred: `~/.audit-dashboard-errors.log`
- Fallback: `/tmp/.audit-dashboard-errors.log`

## In-memory globals
- `RISK`: findings list and score computation
- `SESSION`: session activity tracker
- `UNDO_LOG`: current-session undo entries (mirror of the JSONL)
- `IGNORE_LIST`: ignored findings for current session
- `T`: active theme dict
- `LANG`: active language key
- `PKG_MGR`: detected package manager (`apt`/`dnf`/`pacman`)
- `BASE_FS`: base UI font size
