import AppKit
import FlycutCore
import UniformTypeIdentifiers

/// Imports history and favorites from the original Flycut app.
enum FlycutImporter {
    private static let preferencesName = "com.generalarcade.flycut.plist"

    /// The Mac App Store build is sandboxed; the direct download isn't.
    private static var candidateURLs: [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
        return [
            library.appending(path: "Containers/com.generalarcade.flycut/Data/Library/Preferences/\(preferencesName)"),
            library.appending(path: "Preferences/\(preferencesName)"),
        ]
    }

    /// On first launch, offers to bring over Flycut's history if its data is on this Mac.
    /// Checking that the file exists doesn't read it, so macOS doesn't ask for access until the user agrees.
    static func offerImportIfAvailable(into store: ClipboardStore) {
        guard candidateURLs.contains(where: { FileManager.default.fileExists(atPath: $0.path) }),
              Alerts.confirm(
                  "Import your Flycut history?",
                  "FlycutX found clippings and favorites from Flycut on this Mac. macOS may ask you to allow access to Flycut's data.",
                  action: "Import",
                  cancel: "Not Now"
              )
        else { return }
        run(into: store)
    }

    static func run(into store: ClipboardStore) {
        // Reading another app's container may make macOS ask the user first. If that fails or
        // nothing is found, let them pick the file, which grants access.
        guard let preferences = candidateURLs.lazy.compactMap(readPlist).first ?? chooseFile().flatMap(readPlist) else {
            return
        }
        guard let snapshot = FlycutLegacyImporter.snapshot(fromPreferences: preferences, bundleIdentifier: { Bundle(url: $0)?.bundleIdentifier }) else {
            Alerts.inform("No Flycut history found", "That file doesn't contain any Flycut clippings.")
            return
        }
        let imported = store.importSnapshot(snapshot)
        Alerts.inform(
            "Imported from Flycut",
            "Added \(imported.clippings) clipping\(imported.clippings == 1 ? "" : "s") and \(imported.favorites) favorite\(imported.favorites == 1 ? "" : "s"). Items already in FlycutX were skipped."
        )
    }

    private static func readPlist(at url: URL) -> [String: Any]? {
        NSDictionary(contentsOf: url) as? [String: Any]
    }

    private static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Choose Flycut's preferences file (\(preferencesName))."
        panel.prompt = "Import"
        panel.allowedContentTypes = [.propertyList]
        panel.directoryURL = candidateURLs.first?.deletingLastPathComponent()
        NSApp.activate()
        return panel.runModal() == .OK ? panel.url : nil
    }
}
