import Foundation

/// Reads the history that the original Flycut keeps under the `store` key of its preferences plist
/// (`com.generalarcade.flycut`).
public enum FlycutLegacyImporter {
    /// - Parameters:
    ///   - preferences: The contents of Flycut's preferences plist.
    ///   - bundleIdentifier: Resolves the app bundle path Flycut stored for each clipping.
    /// - Returns: `nil` if the plist has no Flycut history in it.
    public static func snapshot(
        fromPreferences preferences: [String: Any],
        bundleIdentifier: (URL) -> String? = { _ in nil }
    ) -> HistorySnapshot? {
        guard let store = preferences["store"] as? [String: Any],
              store["jcList"] != nil || store["favoritesList"] != nil
        else { return nil }

        func clippings(forKey key: String) -> [Clipping] {
            let entries = store[key] as? [[String: Any]] ?? []
            return entries
                .sorted { position(of: $0) < position(of: $1) }
                .compactMap { entry in
                    guard let text = entry["Contents"] as? String, !text.isEmpty else { return nil }
                    let timestamp = (entry["Timestamp"] as? NSNumber)?.doubleValue ?? 0
                    let appPath = entry["AppBundleURL"] as? String
                    return Clipping(
                        text: text,
                        date: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .now,
                        sourceAppName: entry["AppLocalizedName"] as? String,
                        sourceBundleID: appPath.flatMap { bundleIdentifier(appURL(from: $0)) }
                    )
                }
        }

        return HistorySnapshot(clippings: clippings(forKey: "jcList"), favorites: clippings(forKey: "favoritesList"))
    }

    private static func position(of entry: [String: Any]) -> Int {
        (entry["Position"] as? NSNumber)?.intValue ?? .max
    }

    /// Flycut stored a file system path; tolerate `file://` URLs too.
    private static func appURL(from string: String) -> URL {
        if string.hasPrefix("file://"), let url = URL(string: string) {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}
