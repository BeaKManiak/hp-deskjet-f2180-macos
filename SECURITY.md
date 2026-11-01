# Security

This project asks you to run `sudo` and write files into `/Library`. That deserves an explicit
threat model rather than a reassurance.

## What it runs as root

| Script | Root actions |
|---|---|
| `scripts/20-install.sh` | `ditto` into `/Library/Printers` and `/Library/Image Capture`, `chown`, `chmod`, `xattr` |
| `scripts/30-queue.sh` | `lpadmin` (create queue, set default) |
| `scripts/40-scan-plugin.sh` | `killall icdd` |
| `scripts/99-rollback.sh` | delete exactly the paths listed below, `lpadmin -x`, `killall icdd` |

Nothing installs a kernel extension, launch agent, launch daemon, or background service. Nothing
writes outside the paths listed.

## Paths written

```
/Library/Printers/hp/                                     (removed on rollback)
/Library/Printers/PPDs/Contents/Resources/*.ppd.gz        (only HP PPDs; rollback removes those referencing /Library/Printers/hp/)
/Library/Image Capture/Devices/HPScanner.app              (removed on rollback)
/etc/cups/printers.conf                                   (via lpadmin: one queue)
```

Deliberately **not** written: `/usr/libexec/cups/backend/*` (fax backends in the Apple payload),
`/Library/Extensions/*` (the shipped kext cannot load on modern macOS and is skipped).

## What you are trusting

1. **Apple** — the driver payload is Apple's signed redistributable of HP's macOS driver (package
   id `com.apple.pkg.HewlettPackardPrinterDrivers`). This project does not redistribute those
   binaries; it downloads them from Apple's CDN and verifies SHA-256 before use.
2. **Rosetta 2** — the Intel filters execute under Apple's translation layer. This is the same
   mechanism Apple's own installer would use.
3. **This repository** — ~300 lines of shell and one Swift file. Read them; they are short on
   purpose. Nothing is fetched from a third-party host, and no opaque `.pkg` or prebuilt binary is
   installed.

## Verifying before you run

```sh
# 1. the download is Apple's, unmodified
shasum -a 256 HewlettPackardPrinterDrivers.dmg
# expect 523836b630431bc39b0170a17099099d6f821ef62ff29e6ec64ebb69b9954133

# 2. the package is signed by Apple
pkgutil --check-signature /Volumes/HP_PrinterSupportManual/HewlettPackardPrinterDrivers.pkg
# expect "Status: signed Apple Software"

# 3. the payload matches what this repo was written against
md5 HewlettPackardPrinterDrivers.pkg/Payload   # e0576d1db286a4878d4e89b7d0f0dbd9
md5 HewlettPackardPrinterDrivers.pkg/Bom       # 9acc9cd5d19e6c29bfff6dbd4e8f9270
```

`scripts/00-fetch.sh` and `scripts/10-extract.sh` perform all three checks and refuse to continue on
a mismatch.

## Known limitations

- The driver is unmaintained by HP and Apple; there will be no security fixes. It is user-space
  print/scan code, not a network service, so the exposure is small — but it is not zero.
- It stops working on macOS 28 (Rosetta removal). See `docs/MACOS-28-NEXT-PHASE.md`.
- The installer runs `sudo`, so treat any fork or PR that touches the scripts as a code review of
  root-executed code.

## Reporting

Open an issue for anything that looks wrong. Do not attach printer serials, scan images, or full
system logs to issues.
