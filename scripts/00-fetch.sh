#!/bin/bash
# 00-fetch.sh - download Apple's HP Printer Drivers 10.6 (HP 5.1.1) and verify its SHA-256.
# Touches nothing outside the cache directory.
set -euo pipefail

DMG_URL="https://updates.cdn-apple.com/2021/macos/071-46903-20211101-0BD2764A-901C-41BA-9573-C17B8FDC4D90/HewlettPackardPrinterDrivers.dmg"
DMG_SHA256="523836b630431bc39b0170a17099099d6f821ef62ff29e6ec64ebb69b9954133"

WORK="${1:-$HOME/.cache/hp-f2180}"
DMG="$WORK/HewlettPackardPrinterDrivers.dmg"

mkdir -p "$WORK"

if [ -f "$DMG" ] && printf '%s  %s\n' "$DMG_SHA256" "$DMG" | shasum -a 256 -c - >/dev/null 2>&1; then
    echo "ok: cached download already verifies ($DMG)"
    exit 0
fi

rm -f "$DMG" "$DMG.part"
echo "downloading 557 MB from Apple…"
curl -fL --retry 3 --retry-delay 2 -o "$DMG.part" "$DMG_URL"

echo "verifying SHA-256…"
printf '%s  %s\n' "$DMG_SHA256" "$DMG.part" | shasum -a 256 -c -
mv "$DMG.part" "$DMG"

hdiutil verify "$DMG" >/dev/null
echo "ok: $DMG"
