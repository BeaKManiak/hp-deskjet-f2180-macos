# Why this route and not the obvious ones

## The printer

HP Deskjet F2180 (2007), part of the "Deskjet F2100 series". USB only — no Ethernet, no Wi-Fi, no
network scan protocol. It is an all-in-one: flatbed scanner plus inkjet printer.

From HPLIP's model database (`data/models/models.dat`, `[deskjet_f2100_series]`):

```
tech-class=DJ3320        # proprietary HP raster, not PCL, not PCL3GUI, not PostScript
plugin=0                 # no proprietary HPLIP plugin needed
scan-type=1              # HPMUD_SCANTYPE_SCL - HP's old SCL USB scan protocol
usb-vid=3f0 usb-pid=7d04
```

The DJ3320 detail is the whole story: the printer only understands HP's own raster stream, so a
generic PCL/PostScript driver produces either nothing or garbage.

## Rejected options

| Option | Why it fails here |
|---|---|
| **AirPrint / driverless** | Requires a network-capable printer speaking IPP Everywhere. The F2180 has no network interface at all. |
| **Gutenprint** | Excellent coverage of many old printers, and there is a native arm64 build of it — but Gutenprint never implemented the F-series/DJ3320 engines. Its 3,664-model list contains no F2xxx entry. |
| **HPLIP** | It is the correct open-source driver and supports this model on Linux (hpcups, no plugin required). On macOS: no installer support (`installer/distros.dat` has no Darwin entry), no Homebrew formula, no MacPorts port, only 2013-era forks. And macOS has no SANE client, so a compiled `hpaio` backend would be invisible to Image Capture anyway. |
| **VueScan** | Genuinely supports F2180 scanning on Apple Silicon, native, no Rosetta — but it is paid and does not print. Out of scope for a zero-cost solution. |
| **Community "patched" installer** | Only rewrites the installer's architecture/version checks, and on macOS 27 the repacked archive is corrupt (`cpio read error`). See [FAILED-PATHS.md](FAILED-PATHS.md). |
| **Write a new driver** | Writing a DJ3320 encoder from scratch is months of work to reproduce `hpcups`. Compiling an arm64 build of `hpcups` is the only sensible "own driver" path — still unproven on macOS, and it solves printing only. See [MACOS-28-NEXT-PHASE.md](MACOS-28-NEXT-PHASE.md). |
| **Print server (Pi/NAS)** | Works well (CUPS + hpcups + AirSane) and survives macOS upgrades, but costs hardware — outside the constraints this project was built for. |

## What is actually installed

Apple redistributes HP's macOS driver library as `HewlettPackardPrinterDrivers` 10.6 (HP 5.1.1,
published 2021, "not compatible with macOS 12 and newer"). It contains:

- `HP Deskjet F2100 series.ppd.gz`, whose filter line is already an **absolute path**:
  `*cupsFilter: "application/pdf 100 /Library/Printers/hp/cups/Deskjet.driver/Contents/MacOS/Deskjet"`
  — which is why a manual install works without writing into SIP-protected `/usr/libexec/cups/filter`.
- `Deskjet.driver` — the x86_64 CUPS filter that turns PDF into DJ3320 raster. It links only system
  libraries plus HP frameworks shipped under `/Library/Printers/hp/Frameworks`.
- `HPScanner.app` in `/Library/Image Capture/Devices` — the ICA (ImageKit) plugin for the old
  SCL-protocol scanners. macOS's built-in apps use ICA, so this is what makes Image Capture work
  without SANE.

Only the installer metadata was ever the problem: `hostArchitectures="x86_64"` and an
`InstallationCheck()` that rejects macOS > 15. The binaries themselves run fine under Rosetta 2 —
which is why the last year of macOS 27 is the last year of this printer.

## Why Rosetta is unavoidable

Both halves are Intel-only. Rosetta 2 remains fully supported through macOS 26 and 27 and is
removed in macOS 28. There is no arm64 reimplementation of the DJ3320 raster encoder or of the
F2180's SCL scanner protocol available today.
