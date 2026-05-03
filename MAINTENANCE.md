# MAINTENANCE

**Function:** Operational checklist — recurring tasks, pre-release ritual, environment notes, log/state hygiene, never-commit list, and a router that points new findings to the right tracker file.

Last reviewed: 2026-05-03

---

## Recurring tasks

| Cadence | Task | Where to look |
|---|---|---|
| Per release | Bump version in 3 places: `linux-security-dashboard.py` docstring + window title + `_show_dev_log` header strings; [debian/changelog](debian/changelog); [README.md](README.md) heading | grep `v4.2` across the tree |
| Per release | Update [CHANGELOG.md](CHANGELOG.md) with `### Added / Changed / Fixed / Security` | follow the existing v4.2 template |
| Per release | Refresh [agent_docs/](agent_docs/) — every doc whose mapped surface changed | [CLAUDE.md](CLAUDE.md) — "Specific File Mapping" |
| Quarterly | Re-run a **full Lynis audit** against a clean Ubuntu LTS VM and confirm the parser still extracts `WARNING` / `SUGGESTION` lines from `/var/log/lynis.log` | [linux-security-dashboard.py:3899-3956](linux-security-dashboard.py#L3899-L3956) |
| Quarterly | Re-run **CVE scan** end-to-end against a known-vulnerable package list — confirm `cves.json` schema still matches the `cve_data.get("cves", [])` / `c.get("cvss_severity")` keys we read | [linux-security-dashboard.py:4178-4192](linux-security-dashboard.py#L4178-L4192) |
| Quarterly | Confirm `apt list --upgradable` output format hasn't changed (header line "Listing", per-line `pkg/release version arch [upgradable from: ...]`) | [linux-security-dashboard.py:4294-4340](linux-security-dashboard.py#L4294-L4340) |
| Annually | Refresh `HIGH_VALUE_PKGS` against the actual top-targeted Ubuntu packages | [linux-security-dashboard.py:4022-4027](linux-security-dashboard.py#L4022-L4027) |
| Annually | Cross-check the Guided Wizard fixes against current CIS Level 1 Workstation recommendations | wizard fixes start at [linux-security-dashboard.py:3437](linux-security-dashboard.py#L3437) |
| Annually | Verify `PROFILES` signal lists still match the apps modern users run (Sunshine vs. Moonlight, Lutris vs. Heroic, etc.) | [linux-security-dashboard.py:2649-2695](linux-security-dashboard.py#L2649-L2695) |
| As needed | When packaging deps change, update [debian/control](debian/control) `Depends:` and `Recommends:` to match the runtime probes | grep `shutil.which(` and `pkg_install(` |

---

## Pre-release checklist

Before tagging a release and running `./build-deb.sh`:

- [ ] `python3 -m py_compile linux-security-dashboard.py` — must produce no output.
- [ ] Launch the app on a clean profile (`mv ~/.audit-dashboard.conf{,.bak}; mv ~/.audit-dashboard-undo.log{,.bak}`) and walk the [Startup Wizard](linux-security-dashboard.py#L5900) end-to-end.
- [ ] Manual regression checks per [agent_docs/running_tests.md](agent_docs/running_tests.md):
  - SSH config check passes only on `PermitRootLogin no|prohibit-password` and `PasswordAuthentication no` ([2742-2754](linux-security-dashboard.py#L2742-L2754)).
  - UFW / fail2ban check passes only on **exact** `active` ([2755-2767](linux-security-dashboard.py#L2755-L2767)).
  - Guided Wizard runs SSH fix as 3 sequential commands; refresh ✅/⚠ markers afterward.
  - Action + undo: take a benign action, confirm it appears in the Undo panel with the correct rollback explanation; click UNDO; confirm the row disappears (4-field match — see [agent_docs/known_bugs.md](agent_docs/known_bugs.md)).
  - CVE scan online + offline. Switching CVE → Updates clears stale CVE rows.
  - Drive health invokes `smartctl -H` only — never `-t`. Search the source: `grep -nE "smartctl.*-t" linux-security-dashboard.py` must return nothing.
  - Theme switch updates persistent widgets without restart.
- [ ] Build the `.deb`:

  ```bash
  ./build-deb.sh
  lintian ../linux-security-dashboard_*.deb     # see what regressions packaging warnings flag
  ```

- [ ] Install the `.deb` on a fresh Ubuntu LTS VM (or container with Xvfb): `sudo apt install ../linux-security-dashboard_*.deb` then `linux-security-dashboard`.
- [ ] Confirm desktop entry appears in the menu (Categories: System / Security / Utility) and the icon resolves.
- [ ] Bump [README.md — Roadmap](README.md#L136) checkboxes for anything newly shipped.
- [ ] Update *this* file's "Last reviewed:" date and the same line in any tracker file ([SECURITY.md](SECURITY.md), [PERFORMANCE.md](PERFORMANCE.md), [BUGS.md](BUGS.md), [CODE_REVIEW.md](CODE_REVIEW.md), [ARCHITECTURE.md](ARCHITECTURE.md)) you touched.

---

## Environment notes

### Required at runtime

- Python ≥ 3.10 (uses `walrus :=`, modern type hints, `pathlib`).
- PyQt6 (system package `python3-pyqt6` on Debian/Ubuntu, or `pip install PyQt6 --break-system-packages`).
- `libxcb-cursor0` (Qt 6 runtime requirement on Debian/Ubuntu).

### Detected at runtime, soft-gated

- `deborphan` — needed for `_do_scan_unused`; absence shows a warning rather than crashing ([5493-5497](linux-security-dashboard.py#L5493-L5497)).
- `lynis` — `LynisPanel.run_lynis` offers to install it on demand ([3804-3828](linux-security-dashboard.py#L3804-L3828)).
- `smartmontools` — `run_drive_health_check` offers to install it on demand ([2992-3047](linux-security-dashboard.py#L2992-L3047)).
- `lm-sensors` — `run_temperature_check` advises install path; no auto-install ([2856-2865](linux-security-dashboard.py#L2856-L2865)).
- `timeshift` — `timeshift_is_configured` requires both the binary AND `/etc/timeshift/timeshift.json`. PreActionDialog only shows the snapshot checkbox when both are true ([1882-1900](linux-security-dashboard.py#L1882-L1900)).

### Distro / package-manager support

`detect_distro()` ([577-593](linux-security-dashboard.py#L577-L593)) classifies into `apt` / `dnf` / `pacman`. Inventory and CVE features are apt-only today (see [README.md — Distro Support](README.md#L97)).

---

## Log and state hygiene

### Persistent files (per-user, under `$HOME`)

| Path | Lifecycle | Notes |
|---|---|---|
| `~/.audit-dashboard.conf` | Created on first run; written via atomic temp-replace ([84-94](linux-security-dashboard.py#L84-L94)) | Safe to delete to reset preferences |
| `~/.audit-dashboard-undo.log` | Append-only JSONL; never rotated; loaded fully on UndoPanel init ([4977-4980](linux-security-dashboard.py#L4977-L4980)) | Grows unbounded — if it ever balloons, archive and start fresh: `mv ~/.audit-dashboard-undo.log{,.archive-$(date +%F)}` |
| `~/.audit-dashboard-errors.log` | Python `logging` writes; falls back to `/tmp/.audit-dashboard-errors.log` on permission failure ([57-72](linux-security-dashboard.py#L57-L72)) | Manual rotation when it gets big |
| `~/.audit-dashboard-schedule.log` | Written by the user crontab entry; appended on every cron tick | Monitor size if scheduling daily; rotate via cron's own redirection if needed |
| `~/audit-report-<host>-*.html` | One per RUN EVERYTHING report-open click | Manual cleanup; report files can grow if frequently regenerated |

### System files this app may modify (always with confirmation)

- `/etc/ssh/sshd_config` — wizard SSH hardening, sed in place
- `/etc/sysctl.conf` — wizard core-dump fix (see [B-003](BUGS.md#b-003))
- `/etc/sysctl.d/99-kernel-hardening.conf`
- `/etc/sysctl.d/99-network-hardening.conf`
- `/etc/sysctl.d/99-coredump-hardening.conf` — *will exist after [B-003](BUGS.md#b-003) is fixed*
- `/etc/modprobe.d/uncommon-network.conf`
- `/etc/modprobe.d/uncommon-filesystems.conf`
- `/etc/modprobe.d/blacklist-dma.conf`
- User crontab (only entries with the `# audit-dashboard-schedule` marker)
- Timeshift snapshot store (when user opts in)

When triaging field reports, always check whether the user's `/etc/sysctl.conf` or `/etc/sysctl.d/` has accumulated app-managed entries.

---

## Files never to commit

Already covered by [.gitignore](.gitignore):

- `__pycache__/`
- `*.pyc`, `*.pyo`
- `.venv/`, `venv/`
- `.audit-dashboard.log`
- `.audit-dashboard-history/`

Also avoid committing:

- `~/.audit-dashboard*.log` (anything matching) — contains hostnames and action history.
- `~/.audit-dashboard.conf` — user preferences; specific to one machine.
- Built `.deb` files — written to `../linux-security-dashboard_*.deb` outside the repo by `build-deb.sh`, so unlikely to be staged accidentally; double-check `git status` before any commit immediately after a build.
- `.obsidian/workspace.json` — local Obsidian state; currently shows in `git status` and shouldn't have been tracked.
- Any `*-screenshot-*.png` collected during manual QA.
- Anything under `/tmp/.audit-dashboard-errors.log` from a sudo'd run.

---

## Where does this finding go? (router)

| You found... | Goes in | Section |
|---|---|---|
| A real defect that produces wrong output, crashes, or violates a documented contract | [BUGS.md](BUGS.md) | Open |
| A taste / style preference, or "the code would be cleaner if..." | [CODE_REVIEW.md](CODE_REVIEW.md) | Idiom and style nits |
| Something an attacker (local or remote) could exploit, or a fragile trust boundary | [SECURITY.md](SECURITY.md) | Findings |
| Slow, blocking, leaking, or wasteful — even if functionally correct | [PERFORMANCE.md](PERFORMANCE.md) | Findings |
| A new component, a new persistent file, a new outbound endpoint | [ARCHITECTURE.md](ARCHITECTURE.md) | Component table / Storage paths / Public surface |
| A change in build, runtime deps, or release ritual | This file | Pre-release checklist / Environment notes |
| A surprise system file the app writes | This file | Log and state hygiene |
| A regression that comes back twice | [agent_docs/known_bugs.md](agent_docs/known_bugs.md) | Regression guards (also keep its BUGS.md ID) |
| Behaviour change that contributors should know about | [agent_docs/](agent_docs/) — appropriate file per [CLAUDE.md](CLAUDE.md) mapping | (per-doc) |

When in doubt: write the finding once in the most specific file, cross-reference from the others. Do not duplicate prose across files — it'll drift.

### When updating the review pack

If asked to "update the review pack":

1. Re-read the source paths cited by each open ID. Confirm the line numbers still match (drift is common after refactors).
2. Move resolved IDs to the **Fixed** section of their tracker file. Keep the original ID and append `— Fixed in <commit-or-PR>`. **Never renumber.**
3. Add new findings as the next ID in sequence (`S-010`, `B-011`, etc.).
4. Bump the "Last reviewed:" date on every file you touched.
5. Update `MEMORY.md` (in the user's auto-memory) only if a behaviour rule changed; routine review-pack updates are not memory-worthy.

---

## Cross-references

- [ARCHITECTURE.md](ARCHITECTURE.md) — start here for "what is this thing."
- [SECURITY.md](SECURITY.md), [PERFORMANCE.md](PERFORMANCE.md), [BUGS.md](BUGS.md), [CODE_REVIEW.md](CODE_REVIEW.md) — the four trackers.
- [agent_docs/](agent_docs/) — internal contracts for AI assistants and human contributors. Update those in the same change set as the code; this file's job is to remind you to.
- [CLAUDE.md](CLAUDE.md) — agent operational directives. The "Documentation Authority" rule applies here too.
