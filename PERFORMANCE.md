# PERFORMANCE

**Function:** Efficiency tracker — leaks, missing indexes (n/a here), N+1 patterns, hot paths, blocking I/O, frontend asset cost. This is a single-process Qt GUI with no DB, so most findings are about subprocess fan-out and main-thread blocking.

Last reviewed: 2026-05-03

---

## Findings

### P-001 (LOW) — Single-file 7186-line module loaded on every startup

- **Where:** [linux-security-dashboard.py](linux-security-dashboard.py) — entire app, ~500 KB of source.
- **Impact:** ~150-250 ms of parse + import time at launch on a modern desktop; perceptible cold start. Cached `.pyc` cuts this in half but doesn't eliminate it.
- **Tradeoff:** Splitting the module is a structural change — see [R-001](CODE_REVIEW.md#r-001). Performance gain alone wouldn't justify it; pair with maintainability.
- **Mitigation today:** None.

### P-002 (MEDIUM) — `FindingsTable._sort_by_risk` rebuilds every action-cell widget on every insert

- **Where:** [linux-security-dashboard.py:2400-2471](linux-security-dashboard.py#L2400-L2471). Called from `add_finding` ([2398](linux-security-dashboard.py#L2398)) on every insert outside a bulk window.
- **Pattern:** O(N²) — for the Nth finding inserted we re-create N action-cell widgets (each is a `QWidget` with up to 4 `QPushButton`s, signals, tooltips, and a layout). On a full RUN-EVERYTHING pass with ~100 findings, that's ~5 000 button-widget constructions.
- **Mitigation already in place:** `begin_bulk_update()` / `end_bulk_update()` ([2314-2329](linux-security-dashboard.py#L2314-L2329)) defer sorting until the bulk window closes. Used in `_parse_os` ([5660-5674](linux-security-dashboard.py#L5660-L5674)) and `_parse_user` ([5697-5710](linux-security-dashboard.py#L5697-L5710)) — but **not** in `run_quick_checks`, `run_temperature_check`, `_parse_unused`, `_parse_network`, `_do_scan_services`, `LynisPanel._parse_lynis_output`, or `CvePanel._handle_cve_result`. Most multi-item scans pay full O(N²) cost.
- **Fix:**
  1. Wrap each multi-item scan in `findings.begin_bulk_update()` / `end_bulk_update()`.
  2. Replace the full `_sort_by_risk` widget rebuild with a per-row sort key + `QTableWidget.sortItems()` after enabling sorting only at scan end.
- **User-visible:** RUN EVERYTHING perceivable freeze on the findings table during the steps that produce many rows.

### P-003 (LOW) — `FindingsTable._filter_rows` is O(rows × cols) per keystroke

- **Where:** [linux-security-dashboard.py:2634-2644](linux-security-dashboard.py#L2634-L2644). Wired to `textChanged` ([2135](linux-security-dashboard.py#L2135)) so it fires on every character.
- **Impact:** Linear scan of every cell in every row on each keypress. With <500 findings imperceptible; with the OS-installed scan (~1500 entries on a fresh Ubuntu) noticeable lag on slow keystrokes.
- **Fix:** Debounce with a 150 ms `QTimer.singleShot`, OR build a row→concatenated-text cache once after a scan and `text.lower()` once.

### P-004 (MEDIUM) — `GuidedWizard` runs ~30 sysctl/systemctl subprocesses on the main thread when the dialog opens

- **Where:** [linux-security-dashboard.py:3262-3273](linux-security-dashboard.py#L3262-L3273) (initial check loop) and [3346-3355](linux-security-dashboard.py#L3346-L3355) (`_refresh_fix_statuses` after every fix run). Each `_check_*` calls 1-7 `_run_check`s which each spawn a `subprocess.run([...], timeout=3)` synchronously ([3629-3635](linux-security-dashboard.py#L3629-L3635)).
- **Tally per dialog open:** UFW (1) + fail2ban (1) + SSH (1) + autoupdate (1) + coredump (1) + kernel (3) + network (6) + protocols (1) + filesystems (1) + DMA (1) + apparmor (1) + cad (1) = ~19 subprocesses worst case, plus 4 file probes. ~30 syscalls of fork/exec on the GUI thread.
- **User-visible:** ~300-700 ms blocking freeze when the wizard is opened on a typical desktop.
- **Fix:** Move the initial sweep to a `CommandWorker` (or a single helper `QThread`) that emits a `dict[str, bool]` of statuses on completion. Update the list view in the slot.

### P-005 (LOW) — `RiskScorePanel._section_scores` walks the whole findings table on every score update

- **Where:** [linux-security-dashboard.py:1759-1795](linux-security-dashboard.py#L1759-L1795); called from `update_score` ([1735-1753](linux-security-dashboard.py#L1735-L1753)), which fires on every `score_changed` emission.
- **Impact:** O(N) per score update. With bulk inserts unbatched (see P-002), each row insert triggers a score update which triggers a full table walk. Combined with P-002 the effective complexity is O(N³).
- **Fix:** Maintain a `dict[(section, risk), int]` counter on `FindingsTable` and update incrementally in `add_finding` / `_remove_finding_and_update_score` / `_ignore` / `clear_findings`. Expose a `section_scores()` method that returns the precomputed values.

### P-006 (MEDIUM) — CVE scan is fully sequential — worst-case ~3.7 minutes on flaky links

- **Where:** [linux-security-dashboard.py:1485-1522](linux-security-dashboard.py#L1485-L1522). `HttpWorker.run` loops over `self.packages` one at a time. Per package: `MAX_ATTEMPTS = 2` × `TIMEOUT_SECS = 8` + `time.sleep(attempt)` between retries.
- **Tally:** `HIGH_VALUE_PKGS` is 28 entries ([4022-4027](linux-security-dashboard.py#L4022-L4027)). On a healthy connection: ~3-8 s total. On a saturated link with timeouts: 28 × (8 + 1 + 8) ≈ 7 minutes worst case.
- **Tradeoff:** Parallelising hits the Ubuntu Security tracker harder and risks rate-limiting. A pool of 3-4 concurrent workers would cut typical-case time without abusing the API.
- **Fix:** Either a `ThreadPoolExecutor(max_workers=3)` inside `HttpWorker.run`, or fan out from `CvePanel.scan_cve` into 3-4 `HttpWorker` instances each with a slice of the package list.

### P-007 (LOW) — `ToolsPanel` builds 15 `ToolCard`s on construction, each shelling out to `dpkg -l`

- **Where:** `ToolCard.__init__` calls `self._check_installed()` ([4427](linux-security-dashboard.py#L4427)) which calls `pkg_installed` ([4431](linux-security-dashboard.py#L4431)) which `subprocess.run(["dpkg", "-l", pkg], timeout=5)`. `ToolsPanel.__init__` ([4787-4791](linux-security-dashboard.py#L4787-L4791)) builds one card per `TOOLS_DATA` entry — 15 cards = 15 subprocesses on Tools-tab open.
- **User-visible:** ~150-300 ms freeze on first navigation to the Tools page. Subsequent clicks are free (Qt caches the widget).
- **Fix:** Run a single `dpkg-query -W -f='${Package} ${Status}\n' tool1 tool2 ... toolN` once at panel construction, parse into a `set[str]`, and pass each card the boolean.

### P-008 (LOW) — `_do_scan_services` calls `pkg_installed` per service in a loop

- **Where:** [linux-security-dashboard.py:5609-5615](linux-security-dashboard.py#L5609-L5615) — one `subprocess.run(["dpkg", "-l", name], timeout=5)` per RISKY_SVCS entry (7 entries today).
- **Impact:** Negligible today (≤7 forks). Becomes meaningful if RISKY_SVCS grows.
- **Fix:** Same as P-007 — batch into a single `dpkg-query` call.

### P-009 (LOW) — `make_style()` rebuilds an ~8 KB stylesheet on every theme/font change

- **Where:** [linux-security-dashboard.py:209-440](linux-security-dashboard.py#L209-L440) plus `apply_theme` + `setStyleSheet` re-application throughout.
- **Impact:** A full stylesheet re-apply forces Qt to re-layout every visible widget. On theme switch this is fine (it's a one-shot user action). On every A+/A− press inside `TerminalPanel._adjust_font` ([1626-1631](linux-security-dashboard.py#L1626-L1631)) it's also fine for one press; if the user holds the button (unlikely), it would burn CPU.
- **Fix:** Not worth doing today. Note here as a known hot path so we don't add unnecessary rebuilds.

### P-010 (LOW) — `_re_tick` polls every 400 ms even when nothing is running

- **Where:** [linux-security-dashboard.py:5763-5789](linux-security-dashboard.py#L5763-L5789). `QTimer.singleShot(400, self._re_tick)` inside the "wait for current step" branch.
- **Impact:** Trivial CPU during RUN EVERYTHING. The 400-500 ms latency adds up across 7 steps — a couple of seconds added to every full assessment.
- **Fix:** Wire the next step to the previous worker's `finished_ok` signal instead of polling. The polling-vs-signal tradeoff was made because some steps are synchronous (no worker registers); a tiny adapter that emits a `step_done` signal at the end of every step would resolve both.

### P-011 (LOW) — `_check_ssh` reads sshd_config on every wizard open

- **Where:** [linux-security-dashboard.py:3647-3661](linux-security-dashboard.py#L3647-L3661). Synchronous file read on the main thread; usually fine, but adds to P-004's startup blocking.
- **Fix:** Bundle into the same async batch as P-004's fix.

---

## Hot paths

| Path | Where | Why hot |
|---|---|---|
| `FindingsTable.add_finding` → `_sort_by_risk` → `_build_action_cell` | [2331-2471](linux-security-dashboard.py#L2331-L2471) | Called per scan result; O(N²) widget churn — P-002 |
| `RiskScorePanel.update_score` → `_section_scores` | [1735-1795](linux-security-dashboard.py#L1735-L1795) | Fires on every `score_changed` — P-005 |
| `HttpWorker.run` per-package loop | [1485-1522](linux-security-dashboard.py#L1485-L1522) | Sequential network IO — P-006 |
| `make_style()` rebuild | [209-440](linux-security-dashboard.py#L209-L440) | Full stylesheet on theme/font change — P-009 |

## Blocking I/O on the main thread (audit)

| Caller | Lines | Notes |
|---|---|---|
| `pkg_installed` | [614-632](linux-security-dashboard.py#L614-L632) | `subprocess.run` with 5 s timeout. Called from `_verify`, `ToolCard._check_installed`, `_do_scan_services`, report generator |
| `check_sudo_cached` | [659-669](linux-security-dashboard.py#L659-L669) | 3 s. Cheap; fires on every sudo prompt |
| `has_internet` | [727-737](linux-security-dashboard.py#L727-L737) | 2 s. Fires on every CVE / install path |
| `check_update_age` | [634-657](linux-security-dashboard.py#L634-L657) | File mtime only, not subprocess. Cheap |
| `run_quick_checks` | [2734-2832](linux-security-dashboard.py#L2734-L2832) | 8 sequential subprocesses, 5 s timeout each. ~250-700 ms typical. **Runs on GUI thread** |
| `run_temperature_check` | [2850-2947](linux-security-dashboard.py#L2850-L2947) | Single subprocess. ~50-200 ms. **Runs on GUI thread** |
| `run_drive_health_check` | [2981-3153](linux-security-dashboard.py#L2981-L3153) | One subprocess per drive, 15 s timeout each. **Runs on GUI thread** |
| `GuidedWizard` initial check sweep | [3262-3273](linux-security-dashboard.py#L3262-L3273) | ~30 subprocesses, 3 s timeouts. **Runs on GUI thread** — P-004 |
| `SideBar` machine-info box | [5359-5365](linux-security-dashboard.py#L5359-L5365) | 2 subprocesses, 3 s timeout each. Once at startup. Acceptable |

The async path (`CommandWorker` / `StreamingCommandWorker` / `HttpWorker`) is correctly used for every multi-second operation; the noted exceptions above are the gaps.

---

## Idempotency

- `_fix_coredump` is **not idempotent** — see [S-005](SECURITY.md#s-005). Re-applying the wizard step appends a duplicate line each time.
- All other GuidedWizard fixes write via `> /etc/sysctl.d/...conf` or `> /etc/modprobe.d/...conf` — overwrite, idempotent.
- SSH config edits use `grep -Eq ... && sed ...` ([3491-3504](linux-security-dashboard.py#L3491-L3504)) — idempotent.
- `_act` verifies removal with `pkg_installed(pkg)` ([2570](linux-security-dashboard.py#L2570)); double-clicking REMOVE produces a no-op verify on the second pass.
- Crontab schedule installer drops any existing line marked `# audit-dashboard-schedule` before writing ([4683-4685](linux-security-dashboard.py#L4683-L4685)) — idempotent.

---

## Frontend asset cost

This is a Qt desktop app, not a web frontend. The closest analogue:

- 6 base64-embedded face PNGs ([1031-1041](linux-security-dashboard.py#L1031-L1041)) loaded once into `QPixmap`s; total embedded payload tiny.
- One bundled SVG icon ([packaging/linux-security-dashboard.svg](packaging/linux-security-dashboard.svg)) installed under `/usr/share/icons/hicolor/scalable/apps/`.
- Stylesheet rebuilt on theme/font change — see P-009.

---

## Memory leaks

- `WorkerMixin` removes finished workers from `self._workers` and `deleteLater`s them ([1539-1542](linux-security-dashboard.py#L1539-L1542)) — clean.
- `ToolCard` keeps its own private `_workers` set instead of using `WorkerMixin` ([4361](linux-security-dashboard.py#L4361)). Functionally equivalent but inconsistent — see [R-013](CODE_REVIEW.md#r-013). No leak observed.
- `UNDO_LOG` (in-memory list) grows unbounded across the session — for a desktop tool with at most dozens of actions per session, fine.
- `~/.audit-dashboard-undo.log` grows unbounded across all sessions. No rotation. See [MAINTENANCE.md](MAINTENANCE.md#log-and-state-hygiene).

---

## Benchmarks-TODO

No baselines have been collected yet. Targets to fill in once a measurement harness exists.

| Metric | Path | How to measure | Baseline | Target |
|---|---|---|---|---|
| Cold start to main window | `main()` → `AuditDashboard.__init__` | `time python3 linux-security-dashboard.py` then close immediately | TBD | < 1 s |
| RUN EVERYTHING (online) | `SideBar.run_everything()` to summary dialog | wall-clock; instrument `_re_tick` | TBD | < 30 s |
| RUN EVERYTHING (offline) | as above with `has_internet → False` | wall-clock | TBD | < 10 s |
| CVE scan (28 packages, healthy network) | `CvePanel.scan_cve` | timer in `_finish_cve_scan` | TBD | < 8 s |
| GuidedWizard dialog open | `GuidedWizard.__init__` | timestamp before/after `.exec()` | TBD | < 200 ms |
| Tools tab first open | `_show_tools` switch | UI freeze stopwatch | TBD | < 250 ms |
| Findings table — add 100 rows in bulk | `_parse_os` style insert | wrap with `time.perf_counter` | TBD | < 500 ms |
| Findings table — add 100 rows without bulk window | unbatched scan | as above | TBD | (compare; expect 5-10× worse — P-002 evidence) |
| Theme switch | `_change_theme` | `time.perf_counter` around `setStyleSheet` | TBD | < 150 ms |
| Lynis audit end-to-end | `LynisPanel.run_lynis` | timer in `_parse_lynis_output` | TBD | depends on Lynis itself; record once for trend |

Add a `time.perf_counter()` instrument when the harness lands; do not ship perf logging by default.

---

## Cross-references

- [B-005](BUGS.md#b-005): synchronous-vs-async scan inconsistency — has perf consequences (P-004 / `run_quick_checks` blocks the GUI).
- [R-013](CODE_REVIEW.md#r-013): `ToolCard._workers` tracking pattern.
- [MAINTENANCE.md — log hygiene](MAINTENANCE.md#log-and-state-hygiene): unbounded `~/.audit-dashboard-undo.log` growth.
