import Foundation
import UniformTypeIdentifiers

/// Something captured from the clipboard, plus where and when it came from.
public struct Clipping: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let content: ClipContent
    public var date: Date
    public var sourceAppName: String?
    public var sourceBundleID: String?

    public init(
        id: UUID = UUID(),
        content: ClipContent,
        date: Date = .now,
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil
    ) {
        self.id = id
        self.content = content
        self.date = date
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
    }

    public init(
        id: UUID = UUID(),
        text: String,
        date: Date = .now,
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil
    ) {
        self.init(id: id, content: .text(text), date: date, sourceAppName: sourceAppName, sourceBundleID: sourceBundleID)
    }

    /// The text of a text clipping.
    public var text: String? {
        if case .text(let text) = content { text } else { nil }
    }

    /// The stored data of an image or video clipping.
    public var mediaAsset: MediaAsset? {
        if case .media(let asset) = content { asset } else { nil }
    }

    /// The files of a file clipping.
    public var fileURLs: [URL]? {
        if case .files(let urls) = content { urls } else { nil }
    }

    /// A one-line summary for menus and lists. For text, runs of whitespace (including newlines)
    /// collapse to a single space and long text is cut off with an ellipsis. Only the head of the
    /// text is read, so this stays cheap even for multi-megabyte clippings.
    public func title(maxLength: Int) -> String {
        switch content {
        case .text(let text):
            return Self.collapsed(text, maxLength: maxLength)
        case .media(let asset):
            return Self.collapsed(asset.title, maxLength: maxLength)
        case .files(let urls):
            let first = urls.first?.lastPathComponent ?? "No files"
            let title = urls.count > 1 ? "\(first) + \(urls.count - 1) more" : first
            return Self.collapsed(title, maxLength: maxLength)
        }
    }

    /// What search matches against: the text, the file names, or a description of the media.
    /// Kind words such as "image" and "video" are included so they can be searched for.
    public var searchableText: String {
        switch content {
        case .text(let text):
            return text
        case .media(let asset):
            return [asset.title, asset.kindWords, asset.type?.preferredFilenameExtension ?? ""].joined(separator: " ")
        case .files(let urls):
            let kinds = Set(urls.map { MediaAsset.kindWords(for: UTType(filenameExtension: $0.pathExtension)) })
            return (urls.map(\.lastPathComponent) + kinds.sorted()).joined(separator: " ")
        }
    }

    /// Number of lines in a text clipping (`\r\n` counts as one line break); 0 for other content.
    public var lineCount: Int {
        text?.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        } ?? 0
    }

    private static func collapsed(_ text: String, maxLength: Int) -> String {
        let limit = max(maxLength, 1)
        var result = ""
        var length = 0
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                pendingSpace = length > 0
                continue
            }
            if pendingSpace {
                result.append(" ")
                length += 1
                pendingSpace = false
            }
            result.append(character)
            length += 1
            if length > limit {
                var truncated = String(result.prefix(limit - 1))
                while truncated.last == " " { truncated.removeLast() }
                return truncated + "…"
            }
        }
        return result
    }
}

public enum ClipContent: Hashable, Sendable {
    case text(String)
    /// Image or video data copied straight to the clipboard, such as a screenshot or
    /// "Copy Image". The data itself lives in a `MediaLibrary`.
    case media(MediaAsset)
    /// Files copied in Finder or another app: videos, images, documents. Only references are kept.
    case files([URL])
}

/// Describes image or video data stored in a `MediaLibrary`.
public struct MediaAsset: Codable, Hashable, Sendable {
    /// SHA-256 of the data, in hex. Identical copies share one stored file.
    public var digest: String
    /// The pasteboard type the data was copied as, e.g. `public.png`.
    public var typeIdentifier: String
    public var byteCount: Int
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public init(digest: String, typeIdentifier: String, byteCount: Int, pixelWidth: Int? = nil, pixelHeight: Int? = nil) {
        self.digest = digest
        self.typeIdentifier = typeIdentifier
        self.byteCount = byteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var type: UTType? { UTType(typeIdentifier) }

    public var isVideo: Bool { type?.conforms(to: .movie) == true }

    /// Name of the stored file, e.g. `3f2a….png`.
    public var fileName: String {
        "\(digest).\(type?.preferredFilenameExtension ?? "data")"
    }

    /// E.g. "Image 1920 × 1080" or "Video".
    public var title: String {
        let kind = isVideo ? "Video" : "Image"
        guard let pixelWidth, let pixelHeight else { return kind }
        return "\(kind) \(pixelWidth) × \(pixelHeight)"
    }

    var kindWords: String { Self.kindWords(for: type) }

    static func kindWords(for type: UTType?) -> String {
        guard let type else { return "file" }
        if type.conforms(to: .movie) { return "video movie" }
        if type.conforms(to: .image) { return "image picture photo" }
        if type.conforms(to: .audio) { return "audio sound" }
        if type.conforms(to: .pdf) { return "pdf document" }
        return "file"
    }
}

// Text clippings are stored as `{"text": …}`, exactly as before media support existed, so older
// history files load unchanged. Media and files use their own keys.
extension Clipping: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, date, sourceAppName, sourceBundleID, text, media, files
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            content = .text(text)
        } else if let asset = try container.decodeIfPresent(MediaAsset.self, forKey: .media) {
            content = .media(asset)
        } else {
            content = .files(try container.decode([URL].self, forKey: .files))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        switch content {
        case .text(let text): try container.encode(text, forKey: .text)
        case .media(let asset): try container.encode(asset, forKey: .media)
        case .files(let urls): try container.encode(urls, forKey: .files)
        }
    }
}
