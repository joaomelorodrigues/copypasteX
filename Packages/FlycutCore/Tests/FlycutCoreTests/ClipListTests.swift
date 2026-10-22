import Foundation
import Testing
@testable import FlycutCore

@Suite struct ClipListTests {
    private func texts(_ list: ClipList) -> [String] { list.items.map(\.text) }

    @Test func insertsNewestFirst() {
        var list = ClipList(capacity: 10)
        list.insert(Clipping(text: "a"), removingDuplicates: true)
        list.insert(Clipping(text: "b"), removingDuplicates: true)
        #expect(texts(list) == ["b", "a"])
    }

    @Test func repeatedTopTextOnlyRefreshesDate() {
        var list = ClipList(capacity: 10)
        list.insert(Clipping(text: "a", date: .distantPast), removingDuplicates: false)
        let later = Date(timeIntervalSince1970: 1_000)
        let added = list.insert(Clipping(text: "a", date: later), removingDuplicates: false)
        #expect(!added)
        #expect(list.count == 1)
        #expect(list.items[0].date == later)
    }

    @Test func duplicatesMoveToTopWhenRemoving() {
        var list = ClipList(capacity: 10)
        for text in ["a", "b", "c"] { list.insert(Clipping(text: text), removingDuplicates: true) }
        list.insert(Clipping(text: "a"), removingDuplicates: true)
        #expect(texts(list) == ["a", "c", "b"])
    }

    @Test func duplicatesKeptWhenNotRemoving() {
        var list = ClipList(capacity: 10)
        for text in ["a", "b", "a"] { list.insert(Clipping(text: text), removingDuplicates: false) }
        #expect(texts(list) == ["a", "b", "a"])
    }

    @Test func capacityDropsOldest() {
        var list = ClipList(capacity: 2)
        for text in ["a", "b", "c"] { list.insert(Clipping(text: text), removingDuplicates: true) }
        #expect(texts(list) == ["c", "b"])
        list.capacity = 1
        #expect(texts(list) == ["c"])
        list.capacity = 0
        #expect(list.capacity == 1)
    }

    @Test func moveToTopAndRemove() {
        var list = ClipList(capacity: 10)
        for text in ["a", "b", "c"] { list.insert(Clipping(text: text), removingDuplicates: true) }
        let a = list.items[2]
        list.moveToTop(id: a.id)
        #expect(texts(list) == ["a", "c", "b"])
        #expect(list.remove(id: a.id)?.text == "a")
        #expect(texts(list) == ["c", "b"])
        #expect(list.remove(id: UUID()) == nil)
    }

    @Test func appendSkipsKnownTextAndRespectsCapacity() {
        var list = ClipList(items: [Clipping(text: "a")], capacity: 3)
        let added = list.append(contentsOf: ["a", "b", "b", "c", "d"].map { Clipping(text: $0) })
        #expect(added == 2)
        #expect(texts(list) == ["a", "b", "c"])
    }

    @Test func filterMatchesAllTermsIgnoringCaseAndDiacritics() {
        let list = ClipList(
            items: ["let café = 1", "Cafe latte", "func main()"].map { Clipping(text: $0) },
            capacity: 10
        )
        #expect(list.filtered(by: "CAFE").map(\.text) == ["let café = 1", "Cafe latte"])
        #expect(list.filtered(by: "cafe let").map(\.text) == ["let café = 1"])
        #expect(list.filtered(by: "   ").count == 3)
        #expect(list.filtered(by: "zzz").isEmpty)
    }

    @Test func joinedTextIsChronological() {
        var list = ClipList(capacity: 10)
        for text in ["first", "second"] { list.insert(Clipping(text: text), removingDuplicates: true) }
        #expect(list.joinedText() == "first\nsecond")
    }
}

@Suite struct ClippingTests {
    @Test func titleCollapsesWhitespace() {
        let clipping = Clipping(text: "  func  main()\n{\n\treturn\n}  ")
        #expect(clipping.title(maxLength: 100) == "func main() { return }")
    }

    @Test func titleTruncatesWithEllipsis() {
        let clipping = Clipping(text: "abcdef ghijkl")
        #expect(clipping.title(maxLength: 6) == "abcde…")
        #expect(clipping.title(maxLength: 8) == "abcdef…")
        #expect(clipping.title(maxLength: 13) == "abcdef ghijkl")
    }

    @Test func lineCount() {
        #expect(Clipping(text: "one").lineCount == 1)
        #expect(Clipping(text: "one\ntwo\r\nthree").lineCount == 3)
    }
}
