/// The selected row of a list, with optional wrap-around at the ends.
public struct ListCursor: Equatable, Sendable {
    public private(set) var index = 0

    public var count = 0 {
        didSet { index = clamped(index) }
    }

    /// Whether single steps past either end continue from the other end.
    public var wraps = false

    public init(count: Int = 0, wraps: Bool = false) {
        self.count = count
        self.wraps = wraps
    }

    /// Moves one row at a time; wraps around when enabled.
    public mutating func step(_ delta: Int) {
        guard count > 0 else { return }
        let target = index + delta
        if wraps {
            index = (target % count + count) % count
        } else {
            index = clamped(target)
        }
    }

    /// Moves several rows at once (Page Up/Down); always stops at the ends.
    public mutating func jump(_ delta: Int) {
        index = clamped(index + delta)
    }

    public mutating func moveToStart() {
        index = 0
    }

    public mutating func moveToEnd() {
        index = clamped(count - 1)
    }

    /// Selects `newIndex` if it exists.
    /// - Returns: `false` when the index is out of range.
    @discardableResult
    public mutating func select(_ newIndex: Int) -> Bool {
        guard (0..<count).contains(newIndex) else { return false }
        index = newIndex
        return true
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, 0), max(count - 1, 0))
    }
}
