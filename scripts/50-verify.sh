#!/bin/bash
# 50-verify.sh - read-only sanity checks. Prints ok/FAIL per item; exits non-zero on failure.
set -uo pipefail

FILTER="/Library/Printers/hp/cups/Deskjet.driver/Contents/MacOS/Deskjet"
PPD="/Library/Printers/PPDs/Contents/Resources/HP Deskjet F2100 series.ppd.gz"
PLUGIN="/Library/Image Capture/Devices/HPScanner.app/Contents/MacOS/HPScanner"
FAIL=0

ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=1; }

echo "host"
sw_vers
printf '  arch  %s\n' "$(uname -m)"

echo "rosetta"
if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    ok "x86_64 execution works"
else
    bad "Rosetta missing: softwareupdate --install-rosetta --agree-to-license"
fi

echo "driver files"
if [ -x "$FILTER" ] && file "$FILTER" | grep -q x86_64; then
    ok "Deskjet filter (x86_64)"
else
    bad "Deskjet filter missing or wrong architecture"
fi
[ -f "$PPD" ] && ok "F2100 PPD" || bad "F2100 PPD missing"
if [ -x "$PLUGIN" ] && file "$PLUGIN" | grep -q x86_64; then
    ok "scanner plugin (x86_64)"
else
    bad "scanner plugin missing or wrong architecture"
fi

echo "usb"
if lpinfo -v 2>/dev/null | grep -qi 'usb://HP/Deskjet'; then
    ok "printer enumerated"
    # redact the device serial: it is a unique identifier, not something to paste into issues
    lpinfo -v | grep -i 'usb://HP/Deskjet' | sed -E 's/serial=[^&[:space:]]*/serial=<redacted>/' | sed 's/^/         /'
else
    bad "printer not found on USB"
fi

echo "queue"
lpstat -p -d 2>&1 | sed 's/^/  /'
lpstat -p "${QUEUE:-F2180}" >/dev/null 2>&1 || bad "queue ${QUEUE:-F2180} missing"

echo "scanner daemon"
pgrep -x icdd >/dev/null && ok "icdd running" || bad "icdd not running"

echo
if [ "$FAIL" -eq 0 ]; then
    echo "all checks passed (print/scan tests are manual, see docs/VERIFICATION.md)"
else
    echo "one or more checks failed"
fi
exit "$FAIL"
