#!/bin/bash
# 20-install.sh - copy the verified payload into /Library. Requires root.
set -euo pipefail

WORK="${1:-$HOME/.cache/hp-f2180}"
SRC="$WORK/payload"

[ -d "$SRC/Library/Printers/hp" ] || { echo "error: run scripts/10-extract.sh first" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "error: run with sudo: sudo $0" >&2; exit 1; }

echo "installing drivers into /Library…"
/usr/bin/ditto "$SRC/Library/Printers" /Library/Printers
/usr/bin/ditto "$SRC/Library/Image Capture" "/Library/Image Capture"

# CUPS refuses to run filters that are not root-owned; ownership from cpio is the invoking user.
echo "fixing ownership and permissions…"
chown -R root:wheel /Library/Printers/hp "/Library/Image Capture/Devices/HPScanner.app"
chown -R root:wheel /Library/Printers/PPDs
chmod -R go-w /Library/Printers/hp

/usr/bin/xattr -dr com.apple.quarantine /Library/Printers/hp 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "/Library/Image Capture/Devices/HPScanner.app" 2>/dev/null || true

echo "ok: installed"
