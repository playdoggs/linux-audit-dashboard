# CODE_REVIEW

**Function:** Quality review — what the codebase does well, structural observations, idiom nits, and a "suggested first PR" with the highest-signal small change. This is the file for opinion; objective defects live in [BUGS.md](BUGS.md), security in [SECURITY.md](SECURITY.md), perf in [PERFORMANCE.md](PERFORMANCE.md).

Last reviewed: 2026-05-03

---

## What this codebase does well

Honest, not flattering — these are the things a reviewer should adopt as references for "how to do it right" elsewhere.

### R-W1 — Argv discipline is unbroken across 7 000 lines

A grep for `shell=True`, `os.system`, `os.popen`, `eval(`, or `exec(` returns nothing. Every one of the 30+ `subprocess` call sites passes a list argv. For a tool that runs sudo across dozens of code paths, this is the single most important property — and it holds.

### R-W2 — User-facing transparency is a first-class feature, not a bolt-on

- `PreActionDialog` ([1813-1912](linux-security-dashboard.py#L1813-L1912)) shows the *exact* `sudo <cmd>` before anything runs, plus the undo command if known.
- "SHOW CODE" toolbar entry ([7066-7130](linux-security-dashboard.py#L7066-L7130)) lists every command the app can ever run, organised by category, copy-pasteable.
- `UndoPanel` rows include a "what rollback will do / risk that returns / how it could be used against you" three-part explanation ([5066-5084](linux-security-dashboard.py#L5066-L5084)) sourced from `ROLLBACK_RISK` ([838-887](linux-security-dashboard.py#L838-L887)).
- Optional Timeshift snapshot before any destructive action ([1882-1900](linux-security-dashboard.py#L1882-L1900)) — and snapshot failure **aborts** the action ([2521-2534](linux-security-dashboard.py#L2521-L2534)) instead of silently proceeding. That's the right default.

### R-W3 — Defensive parsing reflects past incidents

The agent_docs/known_bugs.md regression-guards list (anchored regex for SSH config, exact-equality match for `systemctl is-active`, shlex split in the wizard, four-field undo row match) all show up as anchored regexes and exact-string comparisons in the code itself — not as comments saying "TODO." The fixes have been baked in.

### R-W4 — Connectivity-aware features fail loud, not hung

`has_internet()` ([727-737](linux-security-dashboard.py#L727-L737)) gates CVE / install paths and surfaces a clear "⚠ Requires internet" line when offline ([4108-4117](linux-security-dashboard.py#L4108-L4117)). Even when offline, the chained `on_complete` still fires so RUN EVERYTHING doesn't stall. This is well-thought-out and consistent.

### R-W5 — Drive health check is conservative by design

`run_drive_health_check` only ever uses `smartctl -H` ([3091](linux-security-dashboard.py#L3091)) — never `-t`. The comment at [2950-2952](linux-security-dashboard.py#L2950-L2952) makes the constraint explicit so a future contributor adding "advanced" SMART support has to confront the safety case. Plus the drive-name regex validation ([2956, 2976-2978](linux-security-dashboard.py#L2956-L2978)) is defence-in-depth on top of argv.

### R-W6 — `WorkerMixin` is a clean abstraction

`_init_workers` / `_start_worker` / `_stop_all_workers` / `_any_running` ([1526-1557](linux-security-dashboard.py#L1526-L1557)) gives every panel correct lifecycle handling for free. Wired up everywhere except `ToolCard` (see R-013).

### R-W7 — HTML report uses `html.escape()` consistently

Every dynamic value going into the report is escaped at the call site ([6495-6499](linux-security-dashboard.py#L6495-L6499), [6543-6555](linux-security-dashboard.py#L6543-L6555), [6560-6568](linux-security-dashboard.py#L6560-L6568), [6573](linux-security-dashboard.py#L6573)). No template engine, no rope-of-strings vulnerability.

### R-W8 — Risk model is honest

`RiskTracker` ([1155-1195](linux-security-dashboard.py#L1155-L1195)) gives `INFO` zero weight ([1182](linux-security-dashboard.py#L1182)) — inventory and "this check passed" rows show up in the table without inflating the score. Section scoring excludes `OUTDATED` from health impact ([1788-1789](linux-security-dashboard.py#L1788-L1789)) — having an update available isn't itself unhealthy.

---

## Structural observations

### R-001 — 7186 lines, single file

Discussed in [ARCHITECTURE.md — open question 1](ARCHITECTURE.md#open-architectural-questions). The constraint is documented; this review notes the tradeoff: jumping between `FindingsTable` (line 2095), `GuidedWizard` (line 3157), `LynisPanel` (line 3738), `CvePanel` (line 4016), `SideBar` (line 5156) and `AuditDashboard` (line 6691) is doable but not pleasant. A natural first split: `workers.py` (CommandWorker / StreamingCommandWorker / HttpWorker / WorkerMixin), `themes_lang.py` (THEMES, LANGS, make_style, build_palette), `scans.py` (the module-level `run_*_check` functions), keeping the panels and the main window in the entrypoint file. ~3 000 lines come out cleanly.

### R-002 — Heavy reliance on module-level globals

`T`, `LANG`, `BASE_FS`, `RISK`, `SESSION`, `UNDO_LOG`, `IGNORE_LIST`, `PKG_MGR` are all module singletons. Most are read by every panel; `RISK` and `UNDO_LOG` are mutated from many places. Easy to reason about for now but actively hostile to testing — a unit test that wants to assert "after this scan the risk score is X" needs to reset `RISK` between cases. No test suite exists, partly for this reason.

### R-003 — Monkey-patched `QApplication.instance().undo_panel_ref`

[6850](linux-security-dashboard.py#L6850) attaches `undo_panel_ref` to the QApplication. Used by `FindingsTable._verify` ([2596](linux-security-dashboard.py#L2596)) to push live entries to the undo panel. Cleaner: pass `undo_panel` into `FindingsTable.__init__` as an optional ref, or fire a Qt signal `action_logged(entry)` and have the dashboard wire `findings.action_logged → undo_panel.add_live_entry`.

### R-004 — Stylesheet is an 8 KB f-string built per theme/font change

[209-440](linux-security-dashboard.py#L209-L440). Works, but every change in a theme colour means scrolling through ~200 lines of CSS. Splitting per-component (one block for buttons, one for tabs, one for sidebar, etc.) and concatenating would help future-you. Not blocking.

### R-005 — Threat model is well-thought-out for the user persona

Read the rollback explanations in `ROLLBACK_RISK` ([838-887](linux-security-dashboard.py#L838-L887)) and `EXPLANATIONS` ([1918-1961](linux-security-dashboard.py#L1918-L1961)). They reflect a real understanding of *what an attacker actually does with* CUPS / RDP / fail2ban-removed / UFW-disabled. This is rare in security tooling that targets non-experts. Don't lose it.

---

## Idiom and style nits

### R-010 — Inconsistent argv parsing: `shlex.split()` vs `cmd.split()`

`GuidedWizard._run_fix` correctly uses `shlex.split` ([3395](linux-security-dashboard.py#L3395)). `FindingsTable._act` ([2554](linux-security-dashboard.py#L2554)) and `UndoPanel._run_undo` ([5115](linux-security-dashboard.py#L5115)) use `.split()`. Documented as the "use shlex.split" rule in [agent_docs/code_conventions.md](agent_docs/code_conventions.md). Fix is mechanical; tracked as [S-001](SECURITY.md#s-001) / [S-002](SECURITY.md#s-002) / [B-008](BUGS.md#b-008).

### R-011 — `prompt_for_sudo_password` returns a tri-state (bytes / `b""` / `None`)

[813-833](linux-security-dashboard.py#L813-L833). The three states (entered / cached-no-prompt-needed / cancelled) are all callable usefully but every caller has to remember which is which. The current convention is "treat `b""` as success without password and pass it through to `CommandWorker(sudo=True, password=b"")` — but the worker special-cases `if self.sudo and self.password:` ([1287](linux-security-dashboard.py#L1287)) so empty-bytes falls into the else branch (which uses `stdin=DEVNULL` and relies on cached sudo). It works, but it's subtle.

A `dataclass`-style result (`SudoPasswordResult(entered: bool, password: bytes | None, cancelled: bool)`) would make this explicit. Smaller change: rename the tri-state behaviour at the callsites with a comment.

### R-012 — `ToolCard` reimplements worker tracking instead of using `WorkerMixin`

[4361](linux-security-dashboard.py#L4361). Has its own `self._workers = set()`. Functionally equivalent to the mixin. Inherit from `WorkerMixin` and call `_init_workers()`; ~3 line change.

### R-013 — `_section_scores` and `_split_findings` parse data back out of QTableWidgetItems

[1759-1795](linux-security-dashboard.py#L1759-L1795) reads `item.data(UserRole)` (clean) but [6302-6321](linux-security-dashboard.py#L6302-L6321) reads cell text and substring-matches against `"HIGH"`/`"MEDIUM"`/etc. The text format includes emoji + symbol + label (`"🔴 ✖ HIGH"`), so the substring match works — but if the display text changes (e.g. translating risk labels), the parser silently misclassifies. Use the `UserRole` data dict in both paths.

### R-014 — `apply_theme` mutates `T` rather than reassigning it

[170-173](linux-security-dashboard.py#L170-L173). See [B-004](BUGS.md#b-004) — a future theme missing keys would silently inherit values from the previously-active theme. Replace with `T.clear(); T.update(...)`.

### R-015 — `_change_lang` and the rest of `_change_*` are inconsistent in their persistence model

`_change_theme` ([6943-6968](linux-security-dashboard.py#L6943-L6968)) only persists if `self.theme_locked`. `_change_lang` ([7001-7010](linux-security-dashboard.py#L7001-L7010)) always persists. `_toggle_mode` ([6930-6941](linux-security-dashboard.py#L6930-L6941)) always persists. The rationale is reasonable (theme has an explicit lock toggle, language doesn't) but the asymmetry surprises new readers — worth a one-line comment explaining the design.

### R-016 — Status of `INFO` rows in the score is correct but discoverability is poor

`RiskTracker.score()` weights `INFO` at 0 ([1182](linux-security-dashboard.py#L1182)). `_section_scores` skips `OUTDATED`. These are great calls but the only documentation is the inline comment at [1180-1181](linux-security-dashboard.py#L1180-L1181). Worth adding a short paragraph to [agent_docs/service_architecture.md](agent_docs/service_architecture.md) so a future contributor adding a new finding type knows where in the score it lands.

### R-017 — `_parse_upgrades` early-return guard is correct but the comment understates the subtlety

[4294-4310](linux-security-dashboard.py#L4294-L4310). The slot is connected to `output_ready` which fires for both stdout and stderr when the command exits 0 ([1326-1330](linux-security-dashboard.py#L1326-L1330)). The guard avoids double-counting. Worth a one-line note in `CommandWorker.run` next to the dual emission so the contract is documented at the source.

### R-018 — `make_undo_cmd` substring match could collide

[1214-1221](linux-security-dashboard.py#L1214-L1221). `if trigger in cmd:` matches anywhere in the string. Today the triggers are distinctive enough (`"systemctl mask"` won't match `"systemctl masquerade"` because the latter doesn't exist), but a future package named `"apt-purgemate"` would match `"apt purge"` if reversed in the wrong order. Not a current bug; tighten with `re.match(rf"^\s*{re.escape(trigger)}\b", cmd)`.

### R-019 — `_re_tick` polls every 400-500 ms

[5763-5789](linux-security-dashboard.py#L5763-L5789). Discussed as [P-010](PERFORMANCE.md#p-010). The polling pattern was chosen because some queue steps are synchronous (no worker registers); a small `step_done = pyqtSignal()` from each step would let the queue advance event-driven.

---

## Suggested first PR — smallest, highest signal

A single PR with three small, related changes that take ~30 minutes and demonstrably tighten the codebase without architectural risk:

### 1. Switch `_act` and `_run_undo` to `shlex.split`

Replace [linux-security-dashboard.py:2554](linux-security-dashboard.py#L2554) and [5115](linux-security-dashboard.py#L5115) with `shlex.split(cmd)` and `shlex.split(entry["undo_cmd"].removeprefix("sudo "))` respectively.

```python
# was:  CommandWorker(cmd.split(), sudo=True, ...)
import shlex
CommandWorker(shlex.split(cmd), sudo=True, ...)
```

Resolves [B-008](BUGS.md#b-008) and the proximate cause of [S-001](SECURITY.md#s-001) / [S-002](SECURITY.md#s-002). Aligns the code with [agent_docs/code_conventions.md](agent_docs/code_conventions.md).

### 2. Make `_fix_coredump` idempotent

Replace [linux-security-dashboard.py:3525](linux-security-dashboard.py#L3525):

```python
[
    ["sh", "-c", "printf 'fs.suid_dumpable=0\\n' > /etc/sysctl.d/99-coredump-hardening.conf"],
    "sysctl -p /etc/sysctl.d/99-coredump-hardening.conf",
]
```

Resolves [B-003](BUGS.md#b-003) / [S-005](SECURITY.md#s-005). Same pattern as the kernel and network fixes that already use drop-ins.

### 3. Honour `prefs.profile` in `AuditDashboard.__init__`

After [linux-security-dashboard.py:6715](linux-security-dashboard.py#L6715):

```python
saved_profile = cfg.get("prefs", "profile", fallback=None)
if not wizard_result and saved_profile and saved_profile in PROFILES:
    self.profile_key = saved_profile
```

Then change [6890-6893](linux-security-dashboard.py#L6890-L6893) to skip auto-detect when a remembered profile loaded successfully. Resolves [B-002](BUGS.md#b-002).

### Tests / verification

There's no test suite, so verify manually per [agent_docs/running_tests.md](agent_docs/running_tests.md):

- `python3 -m py_compile linux-security-dashboard.py`
- Launch app, run a REMOVE/DISABLE on a benign service, confirm action runs.
- Run "Restrict Core Dumps" twice, confirm `/etc/sysctl.d/99-coredump-hardening.conf` exists with one line, and `/etc/sysctl.conf` was not touched on the second run.
- Tick "Remember this profile" in `ProfileDialog`, restart, confirm the profile dialog does not appear again.

### Single-commit message draft

```
Tighten command parsing, make coredump fix idempotent, honour saved profile

- _act / _run_undo: shlex.split (per code_conventions.md)
- _fix_coredump: write to /etc/sysctl.d drop-in (mirror sibling fixes)
- AuditDashboard.__init__: honour prefs.profile when ProfileDialog ticks "remember"

Resolves: B-002, B-003, B-008. Aligns with S-001 / S-002 / S-005 hardening notes.
```

---

## Cross-references

- [SECURITY.md](SECURITY.md) — items cross-referenced from R-010, R-W2, R-W5, R-W7.
- [BUGS.md](BUGS.md) — items cross-referenced from R-014, R-015, R-018, R-019.
- [PERFORMANCE.md](PERFORMANCE.md) — R-019 surfaces in P-010; R-013 surfaces in P-005.
