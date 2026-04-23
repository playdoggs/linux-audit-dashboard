# Code Conventions

## General
- Keep changes consistent with existing single-file architecture.
- Use worker threads (`CommandWorker`, `HttpWorker`) for slow/blocking operations.
- Do not touch Qt widgets from worker threads.

## Command execution safety
- Prefer explicit argv lists over shell strings.
- Do not use `shell=True`.
- Validate package names with `valid_pkg()` before package-manager actions.
- For commands with shell syntax, store them as a pre-split list (e.g. `['sh', '-c', '...']`) or parse with `shlex.split()` — never `.split()`.

## Security check parsing rules
- Use exact equality for systemd state (`output.strip() == 'active'`, not substring).
- For config checks, use anchored regex that ignores commented lines.

## Connectivity-aware features
- Any feature that needs the network must call `has_internet()` first.
- On failure: surface a `⚠ Requires internet` message in the panel status label and terminal, and still fire any `on_complete` callback so chained flows don't stall.
- Prefer a hard gate for pure-network features (CVE, tool install); a soft warning for features that degrade gracefully (cached `apt list --upgradable`).

## Progress reporting
- Multi-item scans must emit `[N/TOTAL] item — status` lines to the terminal on every iteration.
- Reset the progress counter at scan entry, not in the worker callback.

## Theme/styling
- Persistent widgets should use object names + `make_style()`.
- Avoid persistent inline styles that freeze colors across theme changes.

## Worker lifecycle
- Start workers via `_start_worker()` when available.
- Ensure completion and cleanup signals are connected.

## Shared panels
- A panel used by more than one scan entry point (e.g. `CvePanel`) must clear its widgets at the start of every scan method, not only on one of them.
