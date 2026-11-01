# HP Deskjet F2180 on modern macOS (Apple Silicon)

Make a 2007 USB-only HP Deskjet F2180 print and scan on macOS 26/27 Apple Silicon, using Apple's
own (Intel) HP driver under Rosetta 2 — no paid software, no new hardware, no custom driver.

```
print  → CUPS queue "F2180" + HP's Deskjet.driver filter (x86_64 under Rosetta)
scan   → HP's ICA plugin in Image Capture / Preview (x86_64 under Rosetta)
```

**Status:** verified on macOS 27.2, Mac mini M4, 2026-11-01 — print, scan and survival across a
reboot. **Expires with macOS 28**, when Rosetta 2 is removed. See
[docs/MACOS-28-NEXT-PHASE.md](docs/MACOS-28-NEXT-PHASE.md) before upgrading.

## Why this exists

The F2180 speaks HP's proprietary DJ3320 raster language. Gutenprint never supported the F-series,
HPLIP has no macOS packaging, and HP's own macOS driver (HP 5.1.1 / Apple package 10.6, 2021) is
Intel-only and refuses to install on anything newer than macOS 15. The drivers themselves still
work; only the installer metadata and the CPU architecture get in the way.

Apple's package is the only free thing that drives both the printer and the scanner. This repo
installs its payload directly, verifies it before touching `/Library`, and documents every path it
writes so it can be removed cleanly. Full reasoning and rejected alternatives:
[docs/WHY.md](docs/WHY.md).

## Requirements

- Apple Silicon Mac, macOS 26 or 27 (tested: 27.2 on M4)
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`
- The printer connected by USB and powered on
- ~1.5 GB free disk, `sudo` for the install steps

## Quick start

```sh
git clone https://github.com/<you>/hp-deskjet-f2180-macos.git
cd hp-deskjet-f2180-macos

./scripts/00-fetch.sh          # download Apple's DMG (557 MB) and verify sha256
./scripts/10-extract.sh        # verify Apple signature + payload hashes, extract payload
sudo ./scripts/20-install.sh   # copy driver files into /Library (paths listed below)
./scripts/30-queue.sh          # create the CUPS queue, auto-detecting the USB device URI
./scripts/40-scan-plugin.sh    # restart icdd so Image Capture sees the scanner
./scripts/50-verify.sh         # sanity checks
```

Then print anything, and scan from Image Capture or Preview.

## What gets installed

| Path | Content |
|---|---|
| `/Library/Printers/hp/` | HP CUPS filter (`cups/Deskjet.driver`), frameworks, PPD support, utilities |
| `/Library/Printers/PPDs/Contents/Resources/*.ppd.gz` | HP PPDs, including `HP Deskjet F2100 series.ppd.gz` |
| `/Library/Image Capture/Devices/HPScanner.app` | ICA scanner plugin |

Deliberately **not** installed: the fax backends in `/usr/libexec/cups/backend/` and
`/Library/Extensions/hp_io_enabler_compound.kext` (cannot load on modern macOS). No kernel
extensions, no daemons, no launch agents, no Apple installer receipt.

## Using it

**Print:** any app → Print → `HP Deskjet F2180`. Options: `lpoptions -p F2180 -l`
(default 300x300dpi; 600/1200 supported, `OutputMode` draft→highest, `HPPenConfig=black-only`).

**Scan:** Image Capture → `HP Deskjet F2100 series` → 300 dpi, A4, PDF. Or Preview → File →
Import from Scanner. Or the bundled CLI:

```sh
./tools/build-scan.sh            # needs Xcode Command Line Tools
./tools/f2180-scan ~/Desktop      # writes an A4 300dpi colour PDF
```

## Expected behaviour (not bugs)

| Symptom | Cause |
|---|---|
| Job stays "printing" 30 s–2.5 min after the page comes out | HP filter polls the printer over the USB back-channel before exiting |
| `media-needed` / `media-jam-error` and a stalled queue | Physical: tray empty or jam. Load/clear paper **and press Resume** |
| Blinking cartridge light | Low ink. The driver cannot report ink levels |
| Scanner missing right after install | `icdd` enumerates plugins at startup; run `scripts/40-scan-plugin.sh` |
| "Filter failed" | Check the printer's own error state first (`lpstat -l -p F2180`) |

More: [docs/FAILED-PATHS.md](docs/FAILED-PATHS.md).

## Uninstall

```sh
sudo ./scripts/99-rollback.sh
```

## Security

This project runs `sudo` and writes into `/Library`. What it does, what it trusts, and how to
audit it before running: [SECURITY.md](SECURITY.md).

## License

Scripts and docs: MIT. No Apple or HP binaries are redistributed — the DMG is downloaded from
Apple and verified by SHA-256. Not affiliated with Apple or HP.
