#!/bin/bash
# 99-rollback.sh - remove everything this project installed. Requires root.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "error: run with sudo: sudo $0" >&2; exit 1; }

echo "removing queue…"
lpadmin -x "${QUEUE:-F2180}" 2>/dev/null || true

echo "removing driver…"
rm -rf /Library/Printers/hp

echo "removing HP PPDs (only those pointing at /Library/Printers/hp)…"
for p in /Library/Printers/PPDs/Contents/Resources/*.ppd.gz; do
    [ -e "$p" ] || continue
    if grep -qa "/Library/Printers/hp/" "$p"; then
        rm -f "$p"
    fi
done

echo "removing scanner plugin…"
rm -rf "/Library/Image Capture/Devices/HPScanner.app"

killall icdd 2>/dev/null || true

echo "ok: removed (cached download kept in ${WORK:-$HOME/.cache/hp-f2180}, delete it yourself)"
