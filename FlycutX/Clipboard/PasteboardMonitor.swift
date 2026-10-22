import AppKit
import FlycutCore

/// Watches the general pasteboard for new text.
///
/// macOS has no change notification for the pasteboard, so this polls `changeCount`, which is
/// cheap and never reads content. A generous timer tolerance lets the system coalesce wake-ups.
/// Content is only read after a change, and only once the change has passed the privacy checks.
final class PasteboardMonitor {
    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")

    var isPaused = false
    var policy: () -> CapturePolicy = { CapturePolicy() }
    var onCapture: (Clipping) -> Void = { _ in }

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
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
              let text = pasteboard.string(forType: .string),
              policy.accepts(text)
        else { return }

        let sourceName = sourceID == frontmost?.bundleIdentifier
            ? frontmost?.localizedName
            : sourceID.flatMap(AppInfo.name(for:))
        onCapture(Clipping(text: text, sourceAppName: sourceName, sourceBundleID: sourceID))
    }
}
