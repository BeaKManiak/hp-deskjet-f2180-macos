#!/bin/bash
# 40-scan-plugin.sh - restart icdd so it enumerates the newly installed ICA plugin.
# icdd only scans /Library/Image Capture/Devices at startup.
set -euo pipefail

[ -d "/Library/Image Capture/Devices/HPScanner.app" ] || {
    echo "error: scanner plugin missing, run scripts/20-install.sh first" >&2
    exit 1
}

if pgrep -x icdd >/dev/null; then
    sudo killall icdd
    echo "restarted icdd"
else
    echo "icdd was not running; launchd will start it on demand"
fi

sleep 2
if pgrep -x icdd >/dev/null; then
    echo "ok: icdd running"
else
    echo "warning: icdd not running yet; open Image Capture to trigger it" >&2
fi
