import Foundation

/// copypasteX was called FlycutX in its first release. On first launch, this moves that version's
/// history and settings over. Permissions are tied to the app's identity and can't be carried
/// over, so the onboarding runs again to grant them.
enum RenameMigration {
    private static let oldBundleID = "com.flycutx.FlycutX"
    private static let oldFolderName = "FlycutX"

    static func run() {
        let fileManager = FileManager.default
        let oldFolder = URL.applicationSupportDirectory.appending(path: oldFolderName)
        let newFolder = ClipboardStore.defaultFileURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: oldFolder.path), !fileManager.fileExists(atPath: newFolder.path) {
            try? fileManager.moveItem(at: oldFolder, to: newFolder)
        }

        let defaults = UserDefaults.standard
        guard let bundleID = Bundle.main.bundleIdentifier,
              defaults.persistentDomain(forName: bundleID)?.isEmpty ?? true,
              var settings = defaults.persistentDomain(forName: oldBundleID)
        else { return }
        settings.removeValue(forKey: Preferences.Key.hasLaunchedBefore.rawValue)
        defaults.setPersistentDomain(settings, forName: bundleID)
    }
}
