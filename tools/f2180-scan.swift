// f2180-scan.swift - one-shot A4 300 dpi colour scan via ImageCaptureCore.
// Build: ./build-scan.sh    Usage: ./f2180-scan [output-directory]
import Foundation
import ImageCaptureCore

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : (NSHomeDirectory() + "/Desktop")

final class Probe: NSObject, ICDeviceBrowserDelegate, ICScannerDeviceDelegate {
    var finished = false

    func deviceBrowser(_ b: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard let s = device as? ICScannerDevice else { return }
        s.delegate = self
        s.requestOpenSession()
    }
    func deviceBrowser(_ b: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {}
    func device(_ d: ICDevice, didOpenSessionWithError e: Error?) {}
    func device(_ d: ICDevice, didCloseSessionWithError e: Error?) {}
    func didRemove(_ d: ICDevice) {}

    func deviceDidBecomeReady(_ device: ICDevice) {
        (device as? ICScannerDevice)?.requestSelect(.flatbed)
    }

    func scannerDevice(_ s: ICScannerDevice, didSelect unit: ICScannerFunctionalUnit, error: Error?) {
        if let error {
            FileHandle.standardError.write("select failed: \(error)\n".data(using: .utf8)!)
            finished = true
            return
        }
        unit.measurementUnit = .inches
        // A4. A zero-area scan "completes" instantly and writes nothing.
        unit.scanArea = CGRect(x: 0, y: 0, width: 8.27, height: 11.69)
        if unit.supportedResolutions.contains(300) { unit.resolution = 300 }
        unit.pixelDataType = .RGB

        s.transferMode = .fileBased
        s.documentName = "f2180-scan"
        s.documentUTI = "com.adobe.pdf"
        s.downloadsDirectory = URL(fileURLWithPath: outDir)
        print("scanning \(unit.resolution) dpi -> \(outDir)")
        s.requestScan()
    }

    func scannerDevice(_ s: ICScannerDevice, didScanTo url: URL) {
        print("saved: \(url.path)")
    }

    func scannerDevice(_ s: ICScannerDevice, didCompleteScanWithError error: Error?) {
        if let error {
            FileHandle.standardError.write("scan failed: \(error)\n".data(using: .utf8)!)
        } else {
            print("scan complete")
        }
        finished = true
    }
}

let browser = ICDeviceBrowser()
let probe = Probe()
browser.delegate = probe
browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: 0xFFFFFFFF)!
browser.start()

let deadline = Date().addingTimeInterval(90)
while Date() < deadline && !probe.finished {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
}
browser.stop()

if !probe.finished {
    FileHandle.standardError.write("timeout: no scanner found (is icdd running? is the printer on?)\n".data(using: .utf8)!)
    exit(1)
}
