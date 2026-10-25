import Foundation
import Testing
@testable import CopypasteCore

@Suite struct HistoryFileTests {
    private let url = FileManager.default.temporaryDirectory
        .appending(path: "CopypasteCoreTests-\(UUID().uuidString)")
        .appending(path: "history.json")

    @Test func missingFileLoadsAsNil() throws {
        #expect(try HistoryFile.load(from: url) == nil)
    }

    @Test func roundTripsWithPrivatePermissions() throws {
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let snapshot = HistorySnapshot(
            clippings: [Clipping(text: "hello", date: Date(timeIntervalSince1970: 10), sourceAppName: "Xcode", sourceBundleID: "com.apple.dt.Xcode")],
            favorites: [Clipping(text: "★")]
        )
        try HistoryFile.save(snapshot, to: url)
        #expect(try HistoryFile.load(from: url) == snapshot)

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        try HistoryFile.delete(at: url)
        try HistoryFile.delete(at: url)
        #expect(try HistoryFile.load(from: url) == nil)
    }
}

@Suite struct FlycutLegacyImporterTests {
    @Test func readsHistoryAndFavoritesInPositionOrder() throws {
        let preferences: [String: Any] = [
            "store": [
                "version": "0.7",
                "jcList": [
                    ["Contents": "second", "Type": "NSString", "Position": 1],
                    ["Contents": "first", "Type": "NSString", "Position": 0, "Timestamp": 1_700_000_000,
                     "AppLocalizedName": "Xcode", "AppBundleURL": "/Applications/Xcode.app"],
                    ["Contents": "", "Position": 2],
                ],
                "favoritesList": [
                    ["Contents": "fav", "Position": 0],
                ],
            ] as [String: Any],
        ]
        let snapshot = try #require(FlycutLegacyImporter.snapshot(fromPreferences: preferences) { url in
            url.path == "/Applications/Xcode.app" ? "com.apple.dt.Xcode" : nil
        })
        #expect(snapshot.clippings.map(\.text) == ["first", "second"])
        #expect(snapshot.clippings[0].date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.clippings[0].sourceAppName == "Xcode")
        #expect(snapshot.clippings[0].sourceBundleID == "com.apple.dt.Xcode")
        #expect(snapshot.favorites.map(\.text) == ["fav"])
    }

    @Test func ignoresPlistsWithoutHistory() {
        #expect(FlycutLegacyImporter.snapshot(fromPreferences: [:]) == nil)
        #expect(FlycutLegacyImporter.snapshot(fromPreferences: ["store": [String: Any]()]) == nil)
    }
}
