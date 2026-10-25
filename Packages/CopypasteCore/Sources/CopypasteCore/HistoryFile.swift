import Foundation

/// Everything copypasteX saves to disk.
public struct HistorySnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var clippings: [Clipping]
    public var favorites: [Clipping]

    public init(clippings: [Clipping], favorites: [Clipping]) {
        self.version = Self.currentVersion
        self.clippings = clippings
        self.favorites = favorites
    }
}

/// Reads and writes the history file. Clipboard contents are private, so the file and its
/// folder are readable by the current user only.
public enum HistoryFile {
    /// - Returns: `nil` if there is no history file yet.
    public static func load(from url: URL) throws -> HistorySnapshot? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        return try JSONDecoder().decode(HistorySnapshot.self, from: data)
    }

    public static func save(_ snapshot: HistorySnapshot, to url: URL) throws {
        let fileManager = FileManager.default
        let folder = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func delete(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // Nothing to delete.
        }
    }
}
