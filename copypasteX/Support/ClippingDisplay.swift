import AppKit
import CopypasteCore
import QuickLookThumbnailing
import UniformTypeIdentifiers

extension Clipping {
    /// An SF Symbol for images, videos and files; `nil` for text.
    var kindSymbol: String? {
        switch content {
        case .text:
            return nil
        case .media(let asset):
            return asset.isVideo ? "film" : "photo"
        case .files(let urls):
            guard urls.count == 1, let url = urls.first else { return "doc.on.doc" }
            let type = UTType(filenameExtension: url.pathExtension)
            if type?.conforms(to: .movie) == true { return "film" }
            if type?.conforms(to: .image) == true { return "photo" }
            return url.hasDirectoryPath ? "folder" : "doc"
        }
    }

    /// Longer description for tooltips.
    var summary: String {
        switch content {
        case .text(let text): String(text.prefix(600))
        case .media(let asset): "\(asset.title), \(asset.byteCount.formatted(.byteCount(style: .file)))"
        case .files(let urls): urls.prefix(20).map(\.path).joined(separator: "\n")
        }
    }

    /// Facts for the preview footer, e.g. "PNG image · 1920 × 1080 · 2.4 MB".
    var details: String {
        switch content {
        case .text(let text):
            let characters = text.count
            let lines = lineCount
            return "\(characters.formatted()) character\(characters == 1 ? "" : "s")"
                + (lines > 1 ? " · \(lines.formatted()) lines" : "")
        case .media(let asset):
            var parts = [asset.type?.localizedDescription ?? asset.title]
            if let width = asset.pixelWidth, let height = asset.pixelHeight { parts.append("\(width) × \(height)") }
            parts.append(asset.byteCount.formatted(.byteCount(style: .file)))
            return parts.joined(separator: " · ")
        case .files(let urls):
            // Sizes come from file metadata; skip them for huge selections.
            let sizes = urls.count <= 50 ? urls.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } : []
            let total = sizes.isEmpty ? "" : " · " + sizes.reduce(0, +).formatted(.byteCount(style: .file))
            if urls.count == 1, let url = urls.first {
                let kind = (try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey]).localizedTypeDescription) ?? "File"
                return kind + total
            }
            return "\(urls.count) files" + total
        }
    }
}

/// Thumbnails from Quick Look, the same ones Finder shows: a frame for videos, the picture for
/// images, the first page for documents, the icon for anything else.
enum Thumbnails {
    static func image(for url: URL, size: CGSize, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .all)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
