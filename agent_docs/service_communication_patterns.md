# Communication Patterns

## Command execution flow
1. UI handler creates `CommandWorker`.
2. Worker runs command off the GUI thread.
3. `output_ready`/`error_ready` signals append to terminal.
4. `finished_ok` triggers post-processing (parsing, UI updates, score updates).

## CVE flow
1. `CvePanel.scan_cve()` checks `has_internet()`; skips with a clear message if offline.
2. Builds installed-package target list.
3. `HttpWorker` fetches per-package data from Ubuntu CVE API.
4. `result_ready` updates CVE table, findings, and terminal progress line.
5. `finished_ok` finalizes summary counters.

## Action + undo flow
1. User clicks REMOVE/DISABLE.
2. Sudo password prompt + confirmation dialog.
3. Action runs via `CommandWorker`.
4. Verification updates findings/risk.
5. Undo entry appended in-memory + JSONL + live undo panel.

## RUN EVERYTHING flow
- `SideBar.run_everything()` queues scan steps.
- `_re_tick()` polls worker completion and starts next step.
- Final callback opens `RunEverythingSummaryDialog`.

## Progress reporting convention
- Multi-item scans emit `[N/TOTAL] item — status` lines to the terminal on every item (CVE, risky services, quick checks, available updates).
- Counter resets at scan start; prefix is computed once per iteration.

## Offline / connectivity gates
- `has_internet()` is the single source of truth for connectivity.
- Hard gate (refuse + advise): CVE scan, tool install.
- Soft gate (warn + continue): `apt list --upgradable` (local cache is still usable).
- Always fire any `on_complete` callback even when skipping, so chained flows (RUN EVERYTHING) don't stall.

## Shared-panel reset rule
- `CvePanel` is used by both the CVE button and the Updates button — every entry point MUST call `self.cve_table.setRowCount(0)` before populating, or stale rows leak across scans.

## Thread-safety rule
- All widget mutation must happen in main thread signal handlers.
