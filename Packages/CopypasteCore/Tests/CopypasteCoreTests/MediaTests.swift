import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CopypasteCore

@Suite struct MediaContentTests {
    private let png = MediaAsset(digest: "abc", typeIdentifier: "public.png", byteCount: 2_048, pixelWidth: 1920, pixelHeight: 1080)
    private let movie = MediaAsset(digest: "def", typeIdentifier: "public.mpeg-4", byteCount: 9_000)

    @Test func historyFilesFromBeforeMediaSupportStillLoad() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","text":"hello","date":700000000,"sourceAppName":"Xcode"}"#
        let clipping = try JSONDecoder().decode(Clipping.self, from: Data(json.utf8))
        #expect(clipping.text == "hello")
        #expect(clipping.sourceAppName == "Xcode")
    }

    @Test func allContentKindsRoundTrip() throws {
        let clippings = [
            Clipping(text: "hi"),
            Clipping(content: .media(png), sourceBundleID: "com.apple.screencaptureui"),
            Clipping(content: .files([URL(fileURLWithPath: "/tmp/a b.mov"), URL(fileURLWithPath: "/tmp/c.png")])),
        ]
        let decoded = try JSONDecoder().decode([Clipping].self, from: JSONEncoder().encode(clippings))
        #expect(decoded == clippings)
    }

    @Test func titlesDescribeMediaAndFiles() {
        #expect(Clipping(content: .media(png)).title(maxLength: 50) == "Image 1920 × 1080")
        #expect(Clipping(content: .media(movie)).title(maxLength: 50) == "Video")
        #expect(Clipping(content: .files([URL(fileURLWithPath: "/x/trip.mov")])).title(maxLength: 50) == "trip.mov")
        let two = Clipping(content: .files([URL(fileURLWithPath: "/x/a.png"), URL(fileURLWithPath: "/x/b.png")]))
        #expect(two.title(maxLength: 50) == "a.png + 1 more")
        #expect(two.lineCount == 0)
    }

    @Test func mediaAndFilesAreSearchableByNameAndKind() {
        let list = ClipList(items: [
            Clipping(text: "some text"),
            Clipping(content: .media(png)),
            Clipping(content: .files([URL(fileURLWithPath: "/x/Holiday Trip.mov")])),
        ], capacity: 10)
        #expect(list.filtered(by: "video").count == 1)
        #expect(list.filtered(by: "holiday").count == 1)
        #expect(list.filtered(by: "image png").count == 1)
        #expect(list.filtered(by: "text").count == 1)
    }

    @Test func duplicatesAreDetectedByContent() {
        var list = ClipList(capacity: 10)
        list.insert(Clipping(content: .media(png)), removingDuplicates: true)
        list.insert(Clipping(text: "between"), removingDuplicates: true)
        let added = list.insert(Clipping(content: .media(png)), removingDuplicates: true)
        #expect(added)
        #expect(list.count == 2)
        #expect(list.items.first?.mediaAsset == png)
        #expect(list.mediaFileNames == ["abc.png"])
        #expect(list.joinedText() == "between")
    }
}

@Suite struct MediaLibraryTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "MediaLibraryTests-\(UUID().uuidString)")

    private func pngData(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func describesImageData() throws {
        let data = try pngData(width: 40, height: 30)
        let asset = MediaLibrary.asset(for: data, typeIdentifier: "public.png")
        #expect(asset.digest.count == 64)
        #expect(asset.byteCount == data.count)
        #expect(asset.pixelWidth == 40 && asset.pixelHeight == 30)
        #expect(asset.fileName == "\(asset.digest).png")
        #expect(MediaLibrary.asset(for: data, typeIdentifier: "public.png") == asset)
    }

    @Test func writesPrivatelyAndCollectsGarbage() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = MediaLibrary(folder: folder)
        let first = try pngData(width: 4, height: 4)
        let second = try pngData(width: 8, height: 8)
        let firstAsset = MediaLibrary.asset(for: first, typeIdentifier: "public.png")
        let secondAsset = MediaLibrary.asset(for: second, typeIdentifier: "public.png")
        try library.write(first, for: firstAsset)
        try library.write(first, for: firstAsset)
        try library.write(second, for: secondAsset)

        let attributes = try FileManager.default.attributesOfItem(atPath: library.url(for: firstAsset).path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(try Data(contentsOf: library.url(for: firstAsset)) == first)

        #expect(try library.removeFiles(notIn: [firstAsset.fileName]) == 1)
        #expect(FileManager.default.fileExists(atPath: library.url(for: firstAsset).path))
        #expect(!FileManager.default.fileExists(atPath: library.url(for: secondAsset).path))
    }
}

@Suite struct MediaPolicyTests {
    @Test func browserImageCopiesPreferTheImage() {
        #expect(CapturePolicy.prefersImage(overText: "https://example.com/cat.png"))
        #expect(CapturePolicy.prefersImage(overText: " https://example.com/a?b=c \n"))
        #expect(!CapturePolicy.prefersImage(overText: "see https://example.com"))
        #expect(!CapturePolicy.prefersImage(overText: "Quarterly numbers"))
    }

    @Test func mediaSizeAndToggle() {
        #expect(CapturePolicy().acceptsMedia(byteCount: 1_000))
        #expect(!CapturePolicy().acceptsMedia(byteCount: 0))
        #expect(!CapturePolicy().acceptsMedia(byteCount: CapturePolicy.maxMediaBytes + 1))
        #expect(!CapturePolicy(capturesMedia: false).acceptsMedia(byteCount: 1_000))
    }
}
