# Build Instructions

No compile step. Run Python directly, or build a `.deb`.

## Requirements
- Python 3.10+
- PyQt6
- Optional tools: `deborphan` (unused-package scan), `lynis` (hardening audit), `libxcb-cursor0` (Qt runtime on Debian/Ubuntu)

## Install + Run from source
```bash
sudo apt install python3 python3-pip libxcb-cursor0 deborphan lynis
pip install PyQt6 --break-system-packages
python3 linux-security-dashboard.py
```

## Build the `.deb`
```bash
sudo apt install build-essential debhelper devscripts lintian
./build-deb.sh             # writes ../linux-security-dashboard_*.deb
sudo apt install ../linux-security-dashboard_*.deb
```

The package installs:
- `/usr/lib/linux-security-dashboard/linux-security-dashboard.py`
- `/usr/bin/linux-security-dashboard` (sh wrapper that runs the script)
- `/usr/share/applications/linux-security-dashboard.desktop`
- `/usr/share/icons/hicolor/scalable/apps/linux-security-dashboard.svg`

Packaging metadata lives under `debian/` (control, rules, changelog, copyright, install). Launcher script, desktop entry, and icon are under `packaging/`.

## Runtime files (per-user)
- `~/.audit-dashboard.conf` — preferences
- `~/.audit-dashboard-undo.log` — JSONL rollback log
- `~/.audit-dashboard-errors.log` (fallback: `/tmp/.audit-dashboard-errors.log`)

## Sanity checks
```bash
python3 -m py_compile linux-security-dashboard.py
python3 linux-security-dashboard.py
```

## Size
`linux-security-dashboard.py` — ~7186 lines (2026-04-27).
