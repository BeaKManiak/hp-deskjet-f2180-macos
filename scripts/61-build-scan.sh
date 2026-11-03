#!/bin/bash
# 61-build-scan.sh - Phase C: build HPLIP's hpaio SANE backend for arm64 and see whether
# this printer's SCL scanner path works.
#
# SKELETON. It automates the parts that are known to work (upstream hpaio build for
# Darwin/arm64) and stops where the F2180 needs its own work: HPLIP's scan-type=1 (SCL)
# backend has never been exercised on macOS by the upstream port, which only tested
# scan-type=7 (LEDM). Expect to patch scan/sane/scl.c / sclpml.c here.
#
# Writes inside ./build/scan. The upstream build installs into the Homebrew prefix
# (PREFIX below), which is the only thing outside this repo that it touches.
set -euo pipefail

UPSTREAM="https://github.com/nricaurte/hp-scan-macos"
REF="${REF:-main}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK="${WORK:-$ROOT/build/scan}"
SRC="$WORK/hp-scan-macos"
PREFIX="${PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

xcrun --find clang >/dev/null 2>&1 || die "install Xcode Command Line Tools: xcode-select --install"

missing=()
brew list --versions sane-backends >/dev/null 2>&1 || missing+=(sane-backends)
brew list --versions libusb        >/dev/null 2>&1 || missing+=(libusb)
brew list --versions go            >/dev/null 2>&1 || missing+=(go)
if [ "${#missing[@]}" -gt 0 ]; then
    die "install prerequisites: brew install ${missing[*]}"
fi

mkdir -p "$WORK"
if [ -d "$SRC/.git" ]; then
    say "updating $SRC..."
    git -C "$SRC" fetch --quiet origin "$REF"
    git -C "$SRC" checkout --quiet FETCH_HEAD
else
    say "cloning $UPSTREAM ($REF)..."
    git clone --quiet "$UPSTREAM" "$SRC"
    git -C "$SRC" checkout --quiet "$REF"
fi

say
say "note: this printer is scan-type=1 (SCL). Upstream is tested on scan-type=7 (LEDM)."
say "      If the build fails inside scan/sane/scl.c or sclpml.c, that is expected work,"
say "      not a broken checkout."
say

( cd "$SRC" && PREFIX="$PREFIX" ./build.sh )

say
say "looking for the device..."
SANEDLL="$PREFIX/etc/sane.d/dll.conf"
grep -qx hpaio "$SANEDLL" 2>/dev/null || say "warning: hpaio is not registered in $SANEDLL"

set +e
scanimage -L 2>&1 | sed 's/^/  /'
found=$(scanimage -L 2>/dev/null | grep -ci 'hpaio:.*Deskjet' || true)
set -e

say
if [ "${found:-0}" -gt 0 ]; then
    say "device visible. Try:"
    say "  scanimage -d \"\$(scanimage -L | sed -n 's/.*device \`\(hpaio:[^']*\)'.*/\1/p' | head -1)\" \\"
    say "    --resolution 300 --mode Color -o ~/Desktop/test.pnm"
    say
    say "then expose it to Image Capture (Phase C, session 5):"
    say "  $PREFIX/bin/airscan-bridge &"
    say "  cp \"$SRC/airscan-bridge/com.nricaurte.hp-airscan.plist\" ~/Library/LaunchAgents/"
else
    say "no hpaio device found. Next steps, in order:"
    say "  1. run the build with output visible and check where it stopped"
    say "  2. 'scanimage -L' with SANE_DEBUG_HPAIO=255 for the USB/protocol error"
    say "  3. if hpmud reports a STALL on GET_DEVICE_ID, the musb patch needs adapting"
    say "     for this firmware (see upstream patches/04-musb-macos.patch)"
    say "  4. expect SCL-specific fixes in scan/sane/scl.c / sclpml.c; upstream never"
    say "     ran scan-type=1 on macOS"
fi

say
say "bridge and LaunchAgent details: docs/PHASE-B-C-RUNBOOK.md, Phase C."
