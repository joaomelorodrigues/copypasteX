import Foundation

/// A piece of text captured from the clipboard, plus where and when it came from.
public struct Clipping: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public var date: Date
    public var sourceAppName: String?
    public var sourceBundleID: String?

    public init(
        id: UUID = UUID(),
        text: String,
        date: Date = .now,
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
    }

    /// A one-line summary for menus and lists. Runs of whitespace (including newlines) collapse to a
    /// single space and long text is cut off with an ellipsis. Only the head of the text is read, so
    /// this stays cheap even for multi-megabyte clippings.
    public func title(maxLength: Int) -> String {
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

    /// Number of lines in the text. `\r\n` counts as one line break.
    public var lineCount: Int {
        text.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        }
    }
}
