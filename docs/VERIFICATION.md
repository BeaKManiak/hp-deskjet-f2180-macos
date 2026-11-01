# Verification

## Pinned artifacts

Apple's DMG (`HP 5.1.1 Printer Software Update`, published 2024, build 10.6):

| Artifact | Hash |
|---|---|
| `HewlettPackardPrinterDrivers.dmg` (584,435,157 bytes) | `sha256 523836b630431bc39b0170a17099099d6f821ef62ff29e6ec64ebb69b9954133` |
| `HewlettPackardPrinterDrivers.pkg/Payload` | `md5 e0576d1db286a4878d4e89b7d0f0dbd9` |
| `HewlettPackardPrinterDrivers.pkg/Bom` | `md5 9acc9cd5d19e6c29bfff6dbd4e8f9270` |
| `HewlettPackardPrinterDrivers.pkg/PackageInfo` | `md5 7da37f53e9f5d91b8434be1388988072` |

Source URL is in `scripts/00-fetch.sh` (Apple CDN). `pkgutil --check-signature` reports
`signed Apple Software`.

## Environment tested

| | |
|---|---|
| macOS | 27.2 (build 26B123), arm64 |
| Hardware | Mac mini M4 |
| Printer | HP Deskjet F2180, firmware as shipped, serial redacted |
| Connection | USB-C → USB-A adapter → printer USB-B, direct |
| Rosetta | installed, `arch -x86_64 /usr/bin/true` succeeds |

## Test protocol and results

1. **Print from a PDF** — `lp -d F2180 file.pdf`.
   Result: page printed; queue returned to idle. Observed job lifetime 34 s (one A4 page at
   300 dpi); worst observed 2.5 min on a cold start.
2. **Print from a GUI app** — Preview / browser.
   Result: identical filter chain (`cgtexttopdf` → `Deskjet` → `usb` backend).
3. **Scan** — Image Capture, 300 dpi, colour, A4.
   Result: 1-page PDF, 1.3 MB, `PDF document, version 1.3`.
4. **Scan via CLI** — `tools/f2180-scan <dir>`.
   Result: identical output, no GUI involved.
5. **Reboot persistence** — full reboot, then repeat 1 and 3.
   Result: queue present and default, both operations succeeded, `AutomaticallyInstallMacOSUpdates`
   still `0`.

## Observed state reasons

While active, the job reports HP-specific IPP keywords (`com.hp.s.*`, `com.hp.p.*`) alongside
standard ones. Only these standard ones indicate a problem: `media-needed-*`, `media-jam-*`,
`marker-supply-*`. Everything else is informational noise from HP's state table.
