#!/bin/bash
# 30-queue.sh - create the CUPS queue, auto-detecting the printer's USB device URI.
set -euo pipefail

PPD="/Library/Printers/PPDs/Contents/Resources/HP Deskjet F2100 series.ppd.gz"
QUEUE="${QUEUE:-F2180}"

[ -f "$PPD" ] || { echo "error: PPD missing, run scripts/20-install.sh first" >&2; exit 1; }

DEV="$(lpinfo -v 2>/dev/null | awk '/usb:\/\/HP\/Deskjet/ {print $2; exit}')"
[ -n "${DEV:-}" ] || {
    echo "error: printer not found on USB (check cable and power, then try again)" >&2
    exit 1
}
echo "device: $DEV"

sudo lpadmin -p "$QUEUE" -E -v "$DEV" -P "$PPD" \
    -D "HP Deskjet F2180" -o printer-error-policy=retry-job
sudo lpadmin -d "$QUEUE"

lpstat -p -d -v
