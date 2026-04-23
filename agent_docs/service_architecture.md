# Service Architecture

## Main components
- `AuditDashboard`: main window and orchestration
- `SideBar`: user actions and scan entry points
- `FindingsTable`: shared findings list + actions
- `TerminalPanel`: shared command/log output
- `RiskScorePanel`: score/progress/face/profile status
- `CvePanel`: CVE and upgrade scans (shares one table — must clear on every entry)
- `LynisPanel`: Lynis execution and parsing
- `ToolsPanel` / `ToolCard`: recommended tools install/run/help
- `UndoPanel`: rollback history and execution
- `GuidedWizard`: step-by-step hardening flows
- `StartupWizard`: first-run onboarding
- `RunEverythingSummaryDialog`: post-RUN-EVERYTHING good/needs-fixing assessment
- `SessionSummaryDialog`: "What have I done?" session recap

## Worker model
- `CommandWorker(QThread)`: executes local commands safely (argv lists)
- `HttpWorker(QThread)`: fetches CVE API data with retries/timeouts
- `WorkerMixin`: tracks worker lifecycle and cleanup

## Module-level helpers
- `has_internet(timeout=2.0)`: TCP-connect probe to `1.1.1.1:443`. Used to gate CVE scan, warn on cached `apt list --upgradable`, and block tool installs when offline.
- `get_system_info()`: hostname, distro, kernel, etc. — used by reports and startup banner.
- `check_update_age()`: last `apt update` timestamp driving the health face.
- `check_sudo_cached()`: non-blocking sudo state probe.

## Data flow highlights
- Scans add findings to `FindingsTable`.
- `FindingsTable.score_changed` updates `RiskScorePanel`.
- Successful actions append to `UNDO_LOG`, persist to JSONL, and update `UndoPanel`.
- Reports read from findings + globals (`RISK`, `UNDO_LOG`, profile/system info).
- RUN EVERYTHING chains scans via `SideBar.run_everything()` → `_re_tick()` → `on_complete` → `RunEverythingSummaryDialog`.

## Panel stack indexes
- `0`: Findings
- `1`: CVE (shared by CVE scan + available-updates scan)
- `2`: Lynis
- `3`: Tools
- `4`: Undo
