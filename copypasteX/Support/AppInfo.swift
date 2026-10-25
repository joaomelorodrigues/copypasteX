import AppKit

/// Names and icons of the apps clippings came from, looked up once and cached.
enum AppInfo {
    private static var names: [String: String?] = [:]
    private static var icons: [String: NSImage?] = [:]

    static func name(for bundleID: String) -> String? {
        if let cached = names[bundleID] { return cached }
        let name = url(for: bundleID).map { FileManager.default.displayName(atPath: $0.path).replacing(/\.app$/, with: "") }
        names[bundleID] = name
        return name
    }

    static func icon(for bundleID: String) -> NSImage? {
        if let cached = icons[bundleID] { return cached }
        let icon = url(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        icons[bundleID] = icon
        return icon
    }

    private static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}
