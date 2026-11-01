#!/bin/bash
# 10-extract.sh - verify Apple's package signature, pin the payload hashes, extract the payload.
# Nothing outside the cache directory is modified.
set -euo pipefail

WORK="${1:-$HOME/.cache/hp-f2180}"
DMG="$WORK/HewlettPackardPrinterDrivers.dmg"
VOL="/Volumes/HP_PrinterSupportManual"
PKG="$VOL/HewlettPackardPrinterDrivers.pkg"

# Hashes of Apple's 10.6 payload. If Apple ever republishes a different build, these change:
# do not "fix" them silently, re-verify the package by hand first.
PAYLOAD_MD5="e0576d1db286a4878d4e89b7d0f0dbd9"
BOM_MD5="9acc9cd5d19e6c29bfff6dbd4e8f9270"

[ -f "$DMG" ] || { echo "error: run scripts/00-fetch.sh first" >&2; exit 1; }

cleanup() { hdiutil detach "$VOL" -quiet 2>/dev/null || true; }
trap cleanup EXIT

hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$VOL"
[ -f "$PKG" ] || { echo "error: package not found in DMG" >&2; exit 1; }

echo "checking Apple signature…"
pkgutil --check-signature "$PKG" | grep -q "signed Apple Software" || {
    echo "error: package is not signed by Apple" >&2
    exit 1
}

rm -rf "$WORK/pkg" "$WORK/payload"
mkdir -p "$WORK/pkg" "$WORK/payload"

echo "extracting package…"
( cd "$WORK/pkg" && xar -xf "$PKG" )

echo "pinning payload hashes…"
[ "$(md5 -q "$WORK/pkg/HewlettPackardPrinterDrivers.pkg/Payload")" = "$PAYLOAD_MD5" ] || {
    echo "error: payload MD5 mismatch" >&2
    exit 1
}
[ "$(md5 -q "$WORK/pkg/HewlettPackardPrinterDrivers.pkg/Bom")" = "$BOM_MD5" ] || {
    echo "error: Bom MD5 mismatch" >&2
    exit 1
}

echo "unpacking payload…"
( cd "$WORK/payload" && gunzip -c "$WORK/pkg/HewlettPackardPrinterDrivers.pkg/Payload" | cpio -i -d --quiet )

[ -d "$WORK/payload/Library/Printers/hp" ] || { echo "error: unexpected payload layout" >&2; exit 1; }
echo "ok: $WORK/payload"
