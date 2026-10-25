import Foundation

/// An ordered, size-limited list of clippings, newest first.
public struct ClipList: Equatable, Sendable {
    public private(set) var items: [Clipping]

    /// Maximum number of clippings kept. Lowering it drops the oldest ones.
    public var capacity: Int {
        didSet {
            capacity = max(capacity, 1)
            trim()
        }
    }

    public init(items: [Clipping] = [], capacity: Int) {
        self.items = items
        self.capacity = max(capacity, 1)
        trim()
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    public subscript(id: UUID) -> Clipping? {
        index(of: id).map { items[$0] }
    }

    public func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// Adds `clipping` to the top of the list.
    ///
    /// When the same content is already the newest clipping nothing is added and only its date
    /// is refreshed. With `removingDuplicates`, an older copy of the same content is removed, so
    /// it effectively moves to the top.
    /// - Returns: `true` if a new entry was added.
    @discardableResult
    public mutating func insert(_ clipping: Clipping, removingDuplicates: Bool) -> Bool {
        if items.first?.content == clipping.content {
            items[0].date = clipping.date
            return false
        }
        if removingDuplicates, let index = items.firstIndex(where: { $0.content == clipping.content }) {
            items.remove(at: index)
        }
        items.insert(clipping, at: 0)
        trim()
        return true
    }

    @discardableResult
    public mutating func remove(id: UUID) -> Clipping? {
        guard let index = index(of: id) else { return nil }
        return items.remove(at: index)
    }

    /// Moves a clipping to the top and marks it as just used.
    public mutating func moveToTop(id: UUID, date: Date = .now) {
        guard let index = index(of: id) else { return }
        var clipping = items.remove(at: index)
        clipping.date = date
        items.insert(clipping, at: 0)
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    /// Appends clippings whose content isn't already in the list, keeping their order, up to capacity.
    /// - Returns: How many were added.
    @discardableResult
    public mutating func append(contentsOf clippings: [Clipping]) -> Int {
        var known = Set(items.map(\.content))
        var added = 0
        for clipping in clippings where items.count < capacity && known.insert(clipping.content).inserted {
            items.append(clipping)
            added += 1
        }
        return added
    }

    /// Clippings matching every whitespace-separated term of `query`, ignoring case and diacritics.
    /// Text is matched by content; images and files by name and kind ("image", "video", …).
    public func filtered(by query: String) -> [Clipping] {
        let terms = query.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return items }
        return items.filter { clipping in
            let searchable = clipping.searchableText
            return terms.allSatisfy { searchable.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// All text clippings joined oldest-first, the order they were copied in.
    public func joinedText(separator: String = "\n") -> String {
        items.reversed().compactMap(\.text).joined(separator: separator)
    }

    /// Names of the media files the clippings refer to.
    public var mediaFileNames: Set<String> {
        Set(items.compactMap { $0.mediaAsset?.fileName })
    }

    private mutating func trim() {
        if items.count > capacity {
            items.removeLast(items.count - capacity)
        }
    }
}
