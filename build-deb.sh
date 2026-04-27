#!/bin/sh
# Build a .deb of Linux Security Dashboard from this repository.
# Run from the repo root.  No sudo required for the build itself.
#
# The resulting .deb is written to the parent directory (Debian
# packaging convention) and can be installed with:
#     sudo apt install ../linux-security-dashboard_*.deb

set -e

if ! command -v dpkg-buildpackage >/dev/null 2>&1; then
    cat <<'EOF' >&2
Missing build tools. Install them with:

    sudo apt install build-essential debhelper devscripts lintian

EOF
    exit 1
fi

dpkg-buildpackage -us -uc -b

echo
echo "── Build complete ────────────────────────────────────────"
ls -1 ../linux-security-dashboard_*.deb 2>/dev/null \
    || { echo "  (no .deb produced — check the output above)" >&2; exit 1; }
echo
echo "Install with:"
echo "    sudo apt install ../linux-security-dashboard_*.deb"
echo
echo "Optional sanity check:"
echo "    lintian ../linux-security-dashboard_*.deb"
