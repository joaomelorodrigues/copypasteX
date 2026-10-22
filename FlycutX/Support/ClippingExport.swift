import FlycutCore
import Foundation

enum ClippingExport {
    /// Saves to the Desktop like a screenshot, e.g. "Clipping 2026-10-22 at 08.35.10.txt".
    static func saveToDesktop(_ clipping: Clipping) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let desktop = try FileManager.default.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let url = desktop.appending(path: "Clipping \(formatter.string(from: .now)).txt")
        try clipping.text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
