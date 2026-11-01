# Next phase: surviving macOS 28

**Status: not started. Decision point: before installing macOS 28. Nothing here is proven.**

## Why there is a deadline

Both halves of this project are Intel x86_64 binaries driven by Rosetta 2:

| Component | Path | Architecture |
|---|---|---|
| Print filter | `/Library/Printers/hp/cups/Deskjet.driver/Contents/MacOS/Deskjet` | x86_64 |
| Scanner plugin | `/Library/Image Capture/Devices/HPScanner.app/.../HPScanner` | x86_64 |

Rosetta 2 is supported through macOS 26 and 27 and **removed in macOS 28**. On upgrade day,
printing and scanning both stop, and `installer` metadata patches cannot bring them back.

## Options, honestly compared

| Option | Cost | Effort | Result |
|---|---|---|---|
| **A. Stay on macOS 27** | £0 | none | Printer keeps working indefinitely; Mac stops receiving OS upgrades (security responses continue for a while) |
| **B. Port `hpcups` to arm64** | £0 | 1–3 weekends, 50–60% success | Printing survives macOS 28; scanning still broken |
| **C. Port the scanner stack** | £0 | 2–6 sessions | Scanning via `hpaio` + an eSCL bridge; independent of B |
| **D. Linux print/scan appliance** | ~£40–70 (Pi) | one weekend | Both survive every macOS version; needs always-on hardware |
| **E. Retire the printer** | new printer | none | — |
| **F. VueScan** | ~£65–87 | minutes | Scanning only, native arm64, no Rosetta |

The constraints that shaped this project (zero cost, Mac only) make **A** the default and **B** the
only path to a native solution. D is technically the most robust and is the right answer if the
zero-cost constraint ever relaxes.

## Recommended sequence

1. **Now, while everything works:** capture the state that a future port will need (see checklist).
2. **Before macOS 28 ships:** freeze at 27. Do not let the update install.
3. **Optional, bounded:** attempt B. If it prints, consider C. If B fails after three sessions,
   stop and live with A until the printer is replaced.

## Phase B — arm64 `hpcups`, printing only

### Non-goals

- No reimplementation of the DJ3320 encoder. `hpcups` already is that encoder.
- No modification of Apple's installed tree. The port installs *beside* it so both can be tested.

### Scope

1. Build HPLIP's `libhpmud` + `hpcups` for arm64, reusing the Darwin patches catalogued in
   `nricaurte/hp-scan-macos`:
   - `<unistd.h>` / `<sys/time.h>` for `usleep` / `gettimeofday`
   - `CFPlugInCOM` `ULONG` (32-bit) vs `hpip.h` `ULONG` clash
   - `musb.c`: STALL on IEEE-1284 `GET_DEVICE_ID`; `musb_probe_devices` closing a NULL handle
   - configure paths: `/etc/hp` → a writable prefix
2. Decide the I/O question early — this is the risk: does `hpcups` write raster to stdout (letting
   macOS's own arm64 `usb` backend drive the device), or does it require HPLIP's `hp` backend over a
   socket? If the latter, build `hp` too; both are libusb-based.
3. Reuse HPLIP's `ppd/hpcups/hp-deskjet_f2100_series.ppd` verbatim, but point `*cupsFilter` at the
   absolute path of the new binary (macOS cannot write filters into SIP-protected
   `/usr/libexec/cups/filter`).
4. Ad-hoc codesign every arm64 binary (`codesign --force -s - <file>`); unsigned arm64 binaries are
   killed by the kernel.
5. Install under `/Library/Printers/hp-arm64/` and create a second queue (`F2180-arm64`) so the
   working Rosetta queue is never touched.

### Success test

```sh
lipo -info /Library/Printers/hp-arm64/.../hpcups      # must list arm64
arch -arm64 /Library/Printers/hp-arm64/.../hpcups     # must run without Rosetta
lp -d F2180-arm64 test.pdf                            # must print
```

Then verify the filter actually used is the arm64 one, e.g. `ps` during the job, or a wrapper that
logs `uname -m`. A print that silently fell back to Apple's x86_64 filter proves nothing.

### Stop rule

Three working sessions maximum. If a page has not printed by the end of the third, close the
project: the printer's remaining lifespan does not justify more.

## Phase C — arm64 scanning, if B succeeds

Harder, and independent of B.

1. Build HPLIP's `hpaio` SANE backend for arm64. This model is `scan-type=1` (HPMUD_SCANTYPE_SCL) —
   the old SCL protocol in `scan/sane/scl.c` / `sclpml.c`, not the LEDM path most community ports
   target. Expect extra patches.
2. macOS has **no SANE client**: a working `libsane-hpaio.so` alone changes nothing. Two ways to
   surface it:
   - **eSCL bridge** (proven pattern): run a small server that republishes the SANE device as
     AirScan/eSCL over Bonjour on localhost, so Image Capture, Preview and iOS see it natively.
   - **ICA plugin** (not recommended): write an ImageKit bundle for `/Library/Image Capture/Devices`.
     Much more work, no advantage.
3. Package with a LaunchAgent so the bridge starts at login.
4. Note the USB contention: the print queue can hold the interface. `cupsdisable` → scan →
   `cupsenable` is the known workaround.

## Checklist to capture now (while the Rosetta version still works)

- [ ] Keep this repo, and a copy of Apple's DMG outside git (it is not committed; Apple removes old
      downloads).
- [ ] `cp /etc/cups/ppd/F2180.ppd ~/hp-f2180-archive/` — the exact working PPD as CUPS sees it.
- [ ] `lpoptions -p F2180 -l > ~/hp-f2180-archive/lpoptions.txt`.
- [ ] `system_profiler SPUSBDataType > ~/hp-f2180-archive/usb.txt` while the printer is attached
      (model string, VID/PID 03f0:7d04).
- [ ] One successful job's `error_log` excerpt (`grep "\[Job" /var/log/cups/error_log`), useful to
      compare against a ported filter.
- [ ] Confirm `softwareupdate --list` and the "Install macOS updates" setting before macOS 28 ships.

## Risks

| Risk | Mitigation |
|---|---|
| `hpcups` depends on HPLIP's backend/dbus and resists porting | Timebox; fall back to A |
| No public report of anyone building hpcups on arm64 macOS | Treat first session as pure reconnaissance |
| macOS 28 also changes CUPS filter sandboxing | Verify with a trivial arm64 filter before porting |
| Scanner protocol (`scan-type=1`) is the least-documented path | Do not start C until B is done |
| Apple removes the 10.6 DMG | Keep the local copy; it is the only source of the PPD |

## Decision log (fill in when it happens)

| Date | Decision | Reason |
|---|---|---|
| | | |
