# Dead ends, and the symptoms they produce

Written down so nobody (including future me) spends another evening on them.

## 1. The community "patched" installer package fails on macOS 27

The known fix for installing Apple's HP package on Apple Silicon is to edit the `Distribution` XML
(`hostArchitectures="x86_64,arm64"`, neuter `InstallationCheck()`), repack with `xar`, install. On
macOS 27 this installs to 97% and then fails:

```
PackageKit: Install Failed: PKInstallErrorDomain Code=110
  "An error occurred while extracting files from the package"
  NSUnderlyingError: BOMCopierFatalError Code=1 "cpio read error: bad file format"
  offset=583681756
```

The repack is the problem, not signing: `xar -cf` re-encodes the payload and PackageKit cannot read
it back. `installer -allowUntrusted` does not help.

**What works instead:** use Apple's signed DMG unmodified. Extract the product archive with `xar`,
verify the payload/BOM hashes against the pinned values, unpack the payload with `gunzip | cpio`,
and copy it into `/Library` yourself (`scripts/10-extract.sh`, `scripts/20-install.sh`).

## 2. "cups-insecure-filter-warning"

Extracting a cpio archive as your user yields filter binaries owned by uid 501. CUPS warns and may
refuse to run them:

```
File "/Library/Printers/hp/cups/filters/commandtohp.filter/Contents/MacOS/commandtohp"
has insecure permissions (0100755/uid=501/gid=0)
```

Fix: `chown -R root:wheel /Library/Printers/hp` (done by `20-install.sh`).

## 3. The scanner stays invisible until `icdd` restarts

After copying `HPScanner.app` into `/Library/Image Capture/Devices`, nothing appears — not in Image
Capture, not to ImageCaptureCore. `icdd` enumerates plugins at startup only.

```sh
sudo killall icdd      # launchd restarts it
```

Verified with a small ImageCaptureCore probe: before the restart, zero devices; after, `HP Deskjet
F2100 series`, transport USB.

## 4. A stalled queue is usually paper, not the driver

Long waits and `Filter failed` are what you see when the printer reports a hardware fault. The
actual signal is in the printer's state reasons:

```
lpstat -l -p F2180
  Alerts: offline-report media-needed-warning     # tray empty
  Alerts: offline-report media-jam-error          # jam
```

- `media-needed`: load paper, then **press the Resume button**. The F2180 does not clear this by
  itself; the job stays parked and the queue looks hung.
- `media-jam-error`: clear the paper path; with `printer-error-policy=retry-job` the job re-queues.

Neither is a filter failure, even though CUPS reports it as one.

## 5. Jobs legitimately take 30 s–2.5 min to leave the queue

The HP filter polls the printer over the USB back-channel until the device reports completion,
instead of exiting when the raster is written. `lpstat` shows "now printing / Sending data" while
the page has already come out. Do not cancel and resend — that wastes a sheet.

## 6. A zero-area scan "succeeds" and writes nothing

Using ImageCaptureCore programmatically: `ICScannerFunctionalUnit.scanArea` starts at
`CGRect(0,0,0,0)`. `requestScan()` then completes instantly, reports no error, and produces no file.
Set an explicit area (this repo uses A4) before scanning.

## 7. macOS auto-creates a second queue

Once a working PPD is installed, plugging in the printer makes macOS create its own queue
(`HP_Deskjet_F2100_series`) using the same driver. Two queues on one USB device is harmless while
idle but confusing; delete the extra one (`lpadmin -x`) and keep a single, explicitly configured
queue.
