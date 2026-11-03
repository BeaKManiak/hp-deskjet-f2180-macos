# Runbook: Phase B and C, arm64 print and scan

**Status:** scaffolding committed, nothing installed. Phase B validated up to a working
filter binary and a real DJ3320/Lidil job stream; no page has been printed from it yet.

This is the executable form of [MACOS-28-NEXT-PHASE.md](MACOS-28-NEXT-PHASE.md). It assumes
the full change is wanted: native `hpcups` first, the scanner stack second, then the move to
macOS 28.

## What is already proven (macOS 27.2, Mac mini M4)

| Claim | How it was checked |
|---|---|
| `hpcups` builds for arm64 against macOS's own CUPS | `scripts/60-build-hpcups.sh`; `lipo -info` says `arm64` |
| The filter links only system libraries | `otool -L` lists `/usr/lib/*` only (libjpeg is static) |
| DJ3320 is a fully open encoder in HPLIP | PPD says `*hpPrinterPlatform: "dj3320"`, `*hpPrinterLanguage: "lidil"`; `Lidil.cpp` + `dj3320PrintModes.h` |
| The closed `libImageProcessor` is not needed | it is only created for `ljzjstream` platforms (`HPCupsFilter.cpp`) |
| The raster chain exists on macOS | `/usr/libexec/cups/filter/cgpdftoraster` is present |
| Filter produces printer data | PDF → `cgpdftoraster` → `hpcups` gave 558 KB starting `24 01 00 00` |

What is **not** proven: that the F2180 accepts that stream. That is session 2, and it is the
one thing that decides the whole project.

## Isolation rules

Nothing here may touch the working Rosetta install. See the rollback section of
[MACOS-28-NEXT-PHASE.md](MACOS-28-NEXT-PHASE.md#rollback-back-to-the-rosetta-solution).

- New files live in `/opt/hp-arm64`; nothing goes into `/Library/Printers/hp`.
- The PPD is a copy under `/opt/hp-arm64/share`, never Apple's PPD in place.
- The queue is `F2180-arm64`; `F2180` stays default and untouched.
- After every session: `./scripts/50-verify.sh` and one print on `F2180`.

## Session 0 — preflight (1 h)

Complete the checklist in [MACOS-28-NEXT-PHASE.md](MACOS-28-NEXT-PHASE.md#checklist-to-capture-now-while-the-rosetta-version-still-works),
including the bootable macOS 27 clone. Then:

```sh
sw_vers                       # must be 27.x
./scripts/50-verify.sh        # baseline: all ok
lpstat -p -d
```

Exit: baseline printed and archived, bootable 27 volume exists, DMG cached.

## Session 1 — build (2–3 h)

```sh
brew install jpeg             # build-time only; libjpeg is linked statically
./scripts/60-build-hpcups.sh
```

Output:

```
build/out/hpcups                arm64 filter, DJ3320/Lidil encoder
build/out/hp-f2100-arm64.ppd    *cupsFilter → /opt/hp-arm64/bin/hpcups
```

The script fails loudly if the tarball hash, a patch, or the link line is not what is
expected. Smoke-test the encoder without a printer:

```sh
printf 'hello\n' > /tmp/t.txt
/usr/sbin/cupsfilter -m application/pdf /tmp/t.txt > /tmp/t.pdf
PPD=build/out/hp-f2100-arm64.ppd \
  /usr/libexec/cups/filter/cgpdftoraster 1 me t 1 "" < /tmp/t.pdf > /tmp/t.raster
PPD=build/out/hp-f2100-arm64.ppd build/out/hpcups 1 me t 1 "" /tmp/t.raster > /tmp/t.out
xxd /tmp/t.out | head -1       # 2401 0000 …
```

Exit: arm64 `lipo`, no non-system libraries, non-empty `t.out` starting `24 01`.

## Session 2 — install beside, first page (2 h)

```sh
sudo mkdir -p /opt/hp-arm64/bin /opt/hp-arm64/share
sudo install -o root -g wheel -m 755 build/out/hpcups /opt/hp-arm64/bin/
sudo install -o root -g wheel -m 644 build/out/hp-f2100-arm64.ppd /opt/hp-arm64/share/
sudo codesign --force -s - /opt/hp-arm64/bin/hpcups

DEV="$(lpinfo -v | awk '/usb:\/\/HP\/Deskjet/ {print $2; exit}')"
sudo lpadmin -p F2180-arm64 -E -v "$DEV" -P /opt/hp-arm64/share/hp-f2100-arm64.ppd \
  -D "HP Deskjet F2180 (arm64)" -o printer-error-policy=retry-job

lp -d F2180-arm64 /path/to/test.pdf
ps -Ao pid,arch,comm | grep '[h]pcups'      # must say arm64 while the job runs
```

A page appearing is not proof: check the architecture. If a job "succeeds" but nothing
prints, compare `/var/log/cups/error_log` with the archived successful job from session 0.

Exit: one A4 page from `F2180-arm64`, `F2180` still works.

## Session 3 — harden or stop (3 h)

Colour and greyscale, Draft/Normal/Photo, 300 and 600 dpi, multiple pages, cancel mid-job,
reboot. Check `lpstat -l -p F2180-arm64` for `com.hp.*` noise (informational) versus
`media-needed` / `media-jam` (physical).

**Stop rule:** if no page has printed by the end of this session, stop. Remove the queue and
`/opt/hp-arm64` and keep the Rosetta solution.

Exit: the matrix above passes. Decision point for Phase C.

## Phase C — scanner (sessions 4–6)

The F2180 is `scan-type=1` (HP SCL over USB). The community port that makes `hpaio` build on
Darwin tested `scan-type=7` (LEDM) only, so this is the least-charted part of the project.

**Session 4 — backend (3 h)**

```sh
brew install sane-backends libusb go
./scripts/61-build-scan.sh
```

The script clones `nricaurte/hp-scan-macos`, builds `libsane-hpaio`, and runs `scanimage -L`.
Expected device: `hpaio:/usb/Deskjet_F2100_series?serial=…`.

If nothing appears, work in this order: `SANE_DEBUG_HPAIO=255 scanimage -L`, then the musb
`GET_DEVICE_ID` STALL workaround, then `scan/sane/scl.c` / `sclpml.c`. Budget the session; if
the SCL path needs more than one session of surgery, note it and continue only if B is solid.

**Session 5 — eSCL bridge (2 h)**

macOS has no SANE client, so the backend alone is invisible to Image Capture. The bridge
republishes it as AirScan on loopback:

```sh
$(brew --prefix)/bin/airscan-bridge &
# Image Capture → Shared → "<printer> (USB-bridge)"
```

Exit: Image Capture and Preview import a 300 dpi A4 colour page without any ICA plugin.

**Session 6 — persistence (2 h)**

LaunchAgent for the bridge, USB contention handling (`cupsdisable` → scan → `cupsenable`), and
a cold-boot test. Exit: scan works after reboot with no terminal open.

## Session 7 — macOS 28

1. Install 28 on the **external volume** first; repeat the print and scan tests there.
2. Only then upgrade the internal disk.
3. Back up and remove the x86 tree — `/Library/Printers/hp`, `/Library/Image Capture/Devices/HPScanner.app`,
   every PPD pointing into `/Library/Printers/hp`, and the queues using them. Keep the tarball.
4. Fill in the decision log and update README / `docs/VERIFICATION.md`.

Acceptance test on 28: printing and scanning work while `arch -x86_64 /usr/bin/true` **fails**.

## Definition of done

- [ ] `lipo -info build/out/hpcups` → arm64; `ps -o arch` proves it is the filter used
- [ ] Colour and greyscale, 300/600 dpi, multi-page, reboot — all on `F2180-arm64`
- [ ] Scan from Image Capture over eSCL, 300 dpi A4 PDF, after reboot
- [ ] macOS 28 installed and both paths verified with Rosetta unavailable
- [ ] Rosetta-era driver removed, restore tarball tested
- [ ] README, VERIFICATION, decision log updated

## Specific risks

| Risk | Mitigation |
|---|---|
| Printer rejects the Lidil stream (wrong mode/compression) | Compare against the archived x86 job; `hpcups` picks the same `PlainNormalKColor` mode the PPD declares |
| `hpcups` reads PPD attributes through the deprecated PPD API | Works through 27; if 28 drops it, wrap the same binary in a PAPPL printer application |
| SCL scan path untested on macOS | Timebox session 4; printing is independent and already the bigger win |
| USB interface held by the print queue while scanning | `cupsdisable` / `cupsenable` around the scan |
| Third-party build script drifts | Patch series and HPLIP tarball hash are pinned; the scan repo is pinned by `REF=` |

## Files

| Path | Purpose |
|---|---|
| `scripts/60-build-hpcups.sh` | reproducible arm64 filter build, no install |
| `scripts/61-build-scan.sh` | hpaio build + device check (skeleton for the SCL work) |
| `patches/hplip-3.26.6/0001-darwin-build-fixes.patch` | `<malloc.h>`, case-insensitive `utils.h` collision |
| `patches/hplip-3.26.6/0002-disable-imageprocessor-link.patch` | make `--disable-imageProcessor-build` actually drop `-lImageProcessor` |
| `build/`, `vendor/` | generated, git-ignored |
