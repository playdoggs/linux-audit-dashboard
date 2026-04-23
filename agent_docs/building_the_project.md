# Build Instructions

## Overview
No compile step. Run the Python application directly.

## Requirements
- Python 3.10+
- PyQt6
- Optional feature tools:
  - `deborphan` (unused package scan)
  - `lynis` (hardening audit)
  - `libxcb-cursor0` (common Qt runtime dependency on Debian/Ubuntu)

## Install (example)
```bash
sudo apt install python3 python3-pip libxcb-cursor0 deborphan lynis
pip install PyQt6 --break-system-packages
```

## Run
```bash
python3 linux-security-dashboard.py
```

## Files created at runtime
- `~/.audit-dashboard.conf`
- `~/.audit-dashboard-undo.log`
- `~/.audit-dashboard-errors.log` (or `/tmp/.audit-dashboard-errors.log` fallback)

## Sanity checks
```bash
python3 -m py_compile linux-security-dashboard.py
python3 linux-security-dashboard.py
```

## Current code size
- `linux-security-dashboard.py`: ~6145 lines (2026-04-23).
