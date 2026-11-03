#!/bin/bash
# 60-build-hpcups.sh - build HPLIP's hpcups natively for arm64 (macOS 28 path).
#
# Produces, in ./build/out:
#   hpcups                  arm64 CUPS filter, DJ3320/Lidil encoder, no Rosetta
#   hp-f2100-arm64.ppd      F2100 PPD with *cupsFilter pointing at FILTER_PATH
#
# Writes only inside ./build (and ./vendor for the source tarball). Installs nothing.
# Replaces nothing: the Rosetta driver in /Library/Printers/hp is not touched.
set -euo pipefail

HPLIP_VER=3.26.6
HPLIP_SHA256=5fb2235a9cb6ec07cb4786c4066b151359c301324d54aaabf69ae7eef35606b3
HPLIP_URL="https://downloads.sourceforge.net/project/hplip/hplip/$HPLIP_VER/hplip-$HPLIP_VER.tar.gz"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="${BUILD:-$ROOT/build}"
VENDOR="${VENDOR:-$ROOT/vendor}"
SRC="$BUILD/src"
OUT="$BUILD/out"
TARBALL="$VENDOR/hplip-$HPLIP_VER.tar.gz"
FILTER_PATH="${FILTER_PATH:-/opt/hp-arm64/bin/hpcups}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- prerequisites ---------------------------------------------------------

xcrun --find clang >/dev/null 2>&1 || die "install Xcode Command Line Tools: xcode-select --install"
command -v patch >/dev/null || die "patch(1) not found"
JPEG_PREFIX=$(brew --prefix jpeg 2>/dev/null) || die "install libjpeg: brew install jpeg"
[ -f "$JPEG_PREFIX/include/jpeglib.h" ] || die "jpeglib.h missing under $JPEG_PREFIX"

# --- source ----------------------------------------------------------------

mkdir -p "$VENDOR" "$BUILD"
if [ -f "$TARBALL" ] && printf '%s  %s\n' "$HPLIP_SHA256" "$TARBALL" | shasum -a 256 -c - >/dev/null 2>&1; then
    say "ok: cached $TARBALL"
else
    rm -f "$TARBALL" "$TARBALL.part"
    say "downloading HPLIP $HPLIP_VER..."
    curl -fL --retry 3 --retry-delay 2 -o "$TARBALL.part" "$HPLIP_URL"
    printf '%s  %s\n' "$HPLIP_SHA256" "$TARBALL.part" | shasum -a 256 -c - >/dev/null || {
        rm -f "$TARBALL.part"
        die "sha256 mismatch for $HPLIP_URL"
    }
    mv "$TARBALL.part" "$TARBALL"
fi

rm -rf "$SRC" "$OUT"
mkdir -p "$SRC" "$OUT"
tar -xzf "$TARBALL" -C "$SRC"
SRC="$SRC/hplip-$HPLIP_VER"
cd "$SRC"

say "applying Darwin patches..."
for p in "$ROOT"/patches/hplip-3.26.6/*.patch; do
    patch -p1 -s < "$p" || die "patch failed: $(basename "$p")"
done

# macOS volumes are case-insensitive: prnt/hpcups/Utils.cpp and common/utils.c both
# produce hpcups-Utils.o / hpcups-utils.o, which collide and lose symbols. Rename the
# C source (and its object) so the two are distinct.
mv common/utils.c common/hp_utils.c
perl -pi -e 's{common/utils\.c}{common/hp_utils.c}g; s/hpcups-utils/hpcups-hp_utils/g' Makefile.am Makefile.in
# Do not let make try to re-run automake (1.11 is not available and is not needed).
touch Makefile.in

# Static libjpeg: the filter must not depend on Homebrew at runtime.
mkdir -p "$BUILD/deps/lib"
ln -sf "$JPEG_PREFIX/lib/libjpeg.a" "$BUILD/deps/lib/libjpeg.a"

say "configuring..."
./configure --prefix="$BUILD/prefix" \
    --enable-hpcups-only-build --disable-imageProcessor-build \
    --disable-network-build --disable-scan-build --disable-gui-build \
    --disable-fax-build --disable-dbus-build --disable-doc-build \
    --disable-qt4 --disable-qt5 --disable-pp-build \
    --disable-hpps-install --disable-cups-drv-install \
    CPPFLAGS="-I$JPEG_PREFIX/include" \
    LDFLAGS="-L$BUILD/deps/lib" > "$BUILD/configure.log" 2>&1 \
    || { tail -20 "$BUILD/configure.log" >&2; die "configure failed (see $BUILD/configure.log)"; }

say "building hpcups..."
make -j"$(sysctl -n hw.ncpu)" hpcups > "$BUILD/make.log" 2>&1 \
    || { grep -E 'error:' "$BUILD/make.log" | head -20 >&2; die "make failed (see $BUILD/make.log)"; }

cp hpcups "$OUT/hpcups"
chmod 755 "$OUT/hpcups"

# --- PPD -------------------------------------------------------------------

gunzip -c ppd/hpcups/hp-deskjet_f2100_series.ppd.gz > "$OUT/hp-f2100-arm64.ppd"
# CUPS cannot write filters into SIP-protected /usr/libexec/cups/filter, so the PPD
# names the filter by absolute path. This edits the copy only, never Apple's PPD.
perl -pi -e "s|^\\*cupsFilter:.*|*cupsFilter: \"application/vnd.cups-raster 0 $FILTER_PATH\"|" \
    "$OUT/hp-f2100-arm64.ppd"

# --- report ----------------------------------------------------------------

say
say "built:"
lipo -info "$OUT/hpcups"
say
say "non-system libraries (should be none):"
otool -L "$OUT/hpcups" | tail -n +2 | awk '{print $1}' | grep -v '^/usr/lib/' || say "  (none)"
say
say "archive headers that matter:"
grep -E '^\*(cupsFilter|hpPrinterLanguage|hpPrinterPlatform):' "$OUT/hp-f2100-arm64.ppd"
say
say "next: read docs/PHASE-B-C-RUNBOOK.md, session 2 (install beside the working queue)."
