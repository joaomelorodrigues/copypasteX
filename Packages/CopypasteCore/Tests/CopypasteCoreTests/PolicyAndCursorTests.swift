import Testing
@testable import CopypasteCore

@Suite struct CapturePolicyTests {
    @Test func skipsConcealedTypes() {
        let policy = CapturePolicy()
        #expect(policy.allowsContent(types: ["public.utf8-plain-text"], sourceBundleID: nil))
        #expect(!policy.allowsContent(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"], sourceBundleID: nil))
        #expect(!policy.allowsContent(types: ["com.agilebits.onepassword"], sourceBundleID: nil))
    }

    @Test func skipsIgnoredApps() {
        let policy = CapturePolicy(ignoredBundleIDs: ["com.apple.Passwords"])
        #expect(!policy.allowsContent(types: [], sourceBundleID: "com.apple.Passwords"))
        #expect(policy.allowsContent(types: [], sourceBundleID: "com.apple.dt.Xcode"))
    }

    @Test func whitespaceAndSize() {
        #expect(!CapturePolicy(ignoresWhitespaceOnly: true).accepts(" \n\t"))
        #expect(CapturePolicy(ignoresWhitespaceOnly: false).accepts(" \n\t"))
        #expect(!CapturePolicy().accepts(""))
        #expect(!CapturePolicy().accepts(String(repeating: "x", count: CapturePolicy.maxBytes + 1)))
        #expect(CapturePolicy().accepts("hello"))
    }
}

@Suite struct ListCursorTests {
    @Test func stepsClampWithoutWrap() {
        var cursor = ListCursor(count: 3)
        cursor.step(-1)
        #expect(cursor.index == 0)
        cursor.step(5)
        #expect(cursor.index == 2)
    }

    @Test func stepsWrap() {
        var cursor = ListCursor(count: 3, wraps: true)
        cursor.step(-1)
        #expect(cursor.index == 2)
        cursor.step(1)
        #expect(cursor.index == 0)
    }

    @Test func jumpsNeverWrap() {
        var cursor = ListCursor(count: 25, wraps: true)
        cursor.jump(10)
        cursor.jump(10)
        cursor.jump(10)
        #expect(cursor.index == 24)
        cursor.jump(-100)
        #expect(cursor.index == 0)
    }

    @Test func selectAndShrink() {
        var cursor = ListCursor(count: 10)
        let selectedLast = cursor.select(9)
        let selectedPastEnd = cursor.select(10)
        #expect(selectedLast)
        #expect(!selectedPastEnd)
        #expect(cursor.index == 9)
        cursor.count = 4
        #expect(cursor.index == 3)
        cursor.count = 0
        #expect(cursor.index == 0)
        cursor.step(1)
        #expect(cursor.index == 0)
    }

    @Test func startAndEnd() {
        var cursor = ListCursor(count: 5)
        cursor.moveToEnd()
        #expect(cursor.index == 4)
        cursor.moveToStart()
        #expect(cursor.index == 0)
    }
}
