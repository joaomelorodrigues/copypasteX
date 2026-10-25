import CopypasteCore
import Foundation

enum ClippingExport {
    /// Saves to the Desktop like a screenshot, e.g. "Clipping 2026-10-22 at 08.35.10.txt".
    /// Images and videos keep their format. File clippings already are files, so they can't be saved.
    static func saveToDesktop(_ clipping: Clipping, media: MediaLibrary) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let desktop = try FileManager.default.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let name = "Clipping \(formatter.string(from: .now))"

        switch clipping.content {
        case .text(let text):
            let url = desktop.appending(path: "\(name).txt")
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        case .media(let asset):
            let url = desktop.appending(path: "\(name).\(asset.type?.preferredFilenameExtension ?? "data")")
            try FileManager.default.copyItem(at: media.url(for: asset), to: url)
            return url
        case .files:
            throw CocoaError(.featureUnsupported)
        }
    }
}
