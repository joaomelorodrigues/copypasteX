import AppKit
import CopypasteCore

/// Watches the general pasteboard for new text.
///
/// macOS has no change notification for the pasteboard, so this polls `changeCount`, which is
/// cheap and never reads content. A generous timer tolerance lets the system coalesce wake-ups.
/// Content is only read after a change, and only once the change has passed the privacy checks.
final class PasteboardMonitor {
    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")

    /// Image and video types worth keeping, best first. Compressed formats come before TIFF,
    /// which apps often add as a large, uncompressed duplicate.
    static let mediaTypes: [NSPasteboard.PasteboardType] = [
        .png, .init("public.jpeg"), .init("public.heic"), .init("com.compuserve.gif"), .tiff,
        .init("public.mpeg-4"), .init("com.apple.quicktime-movie"),
    ]

    var isPaused = false
    var policy: () -> CapturePolicy = { CapturePolicy() }
    /// Receives each new clipping, plus the data to store for image and video clippings.
    var onCapture: (Clipping, Data?) -> Void = { _, _ in }

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        // Whatever is on the clipboard at launch was copied before we were watching.
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Ignore the change we just made ourselves.
    func skipCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard !isPaused else { return }
        capture()
    }

    private func capture() {
        let types = pasteboard.types ?? []
        let frontmost = NSWorkspace.shared.frontmostApplication
        let sourceID = types.contains(Self.sourceType)
            ? pasteboard.string(forType: Self.sourceType)
            : frontmost?.bundleIdentifier
        guard sourceID != Bundle.main.bundleIdentifier else { return }

        let policy = policy()
        guard policy.allowsContent(types: types.map(\.rawValue), sourceBundleID: sourceID),
              let (content, data) = readContent(types: Set(types), policy: policy)
        else { return }

        let sourceName = sourceID == frontmost?.bundleIdentifier
            ? frontmost?.localizedName
            : sourceID.flatMap(AppInfo.name(for:))
        onCapture(Clipping(content: content, sourceAppName: sourceName, sourceBundleID: sourceID), data)
    }

    /// Files win, since Finder also adds their names as text and their icons as images. Then
    /// text, unless it's just the address of a copied image. Then image or video data.
    private func readContent(types: Set<NSPasteboard.PasteboardType>, policy: CapturePolicy) -> (ClipContent, Data?)? {
        if policy.capturesFiles, types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return (.files(urls), nil)
        }

        let mediaType = policy.capturesMedia ? Self.mediaTypes.first(where: types.contains) : nil
        if types.contains(.string), let text = pasteboard.string(forType: .string), policy.accepts(text),
           mediaType == nil || !CapturePolicy.prefersImage(overText: text) {
            return (.text(text), nil)
        }

        guard let mediaType, let data = pasteboard.data(forType: mediaType), policy.acceptsMedia(byteCount: data.count) else {
            return nil
        }
        return (.media(MediaLibrary.asset(for: data, typeIdentifier: mediaType.rawValue)), data)
    }
}
