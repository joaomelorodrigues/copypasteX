import CryptoKit
import Foundation
import ImageIO

/// Stores image and video data copied to the clipboard: one file per distinct content, named by
/// its SHA-256 digest, readable only by the current user.
public struct MediaLibrary: Sendable {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public func url(for asset: MediaAsset) -> URL {
        folder.appending(path: asset.fileName)
    }

    /// Describes `data` without storing it. Image dimensions are read from the header only.
    public static func asset(for data: Data, typeIdentifier: String) -> MediaAsset {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        var asset = MediaAsset(digest: digest, typeIdentifier: typeIdentifier, byteCount: data.count)
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            asset.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
            asset.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
        }
        return asset
    }

    /// Writes the data unless an identical copy is already stored.
    public func write(_ data: Data, for asset: MediaAsset) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let url = url(for: asset)
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Deletes stored files that no clipping refers to any more.
    /// - Returns: How many files were deleted.
    @discardableResult
    public func removeFiles(notIn keep: Set<String>) throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder.path) else { return 0 }
        var removed = 0
        for name in try fileManager.contentsOfDirectory(atPath: folder.path) where !keep.contains(name) {
            try fileManager.removeItem(at: folder.appending(path: name))
            removed += 1
        }
        return removed
    }
}
