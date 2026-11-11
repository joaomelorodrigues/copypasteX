import AppKit
import Carbon.HIToolbox
import CopypasteCore

/// Puts clippings back on the pasteboard and, when asked, pastes them into the frontmost app.
final class Paster {
    private let store: ClipboardStore
    private let prefs: Preferences
    private let monitor: PasteboardMonitor
    private var didPromptForAccessibility = false
    private var tiffProvider: TIFFProvider?
    private let pasteboard: NSPasteboard

    init(store: ClipboardStore, prefs: Preferences, monitor: PasteboardMonitor, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.pasteboard = pasteboard
        self.prefs = prefs
        self.monitor = monitor
    }

    /// Copies `clipping` and, if `paste` is true, sends ⌘V to the frontmost app.
    func use(_ clipping: Clipping, from kind: StoreKind, paste: Bool) {
        guard copy(clipping.content) else {
            NSSound.beep()
            return
        }
        // With the setting off, using a clipping leaves the history in the order things were copied.
        if prefs.moveToTopOnPaste {
            switch kind {
            case .history:
                store.moveToTop(clipping.id, in: .history)
            case .favorites:
                // A favorite on the clipboard is now the most recent clipping too.
                store.record(Clipping(content: clipping.content, sourceAppName: clipping.sourceAppName, sourceBundleID: clipping.sourceBundleID))
            }
        }
        guard paste else { return }
        Task {
            // Give the target app a moment to get keyboard focus back from the bezel or menu.
            try? await Task.sleep(for: .milliseconds(60))
            if !Self.sendPasteKeystroke() && !didPromptForAccessibility {
                didPromptForAccessibility = true
                Permissions.requestAccessibility()
            }
        }
    }

    /// Puts content on the clipboard: text as text, files as file references (so Finder and chat
    /// apps paste the files themselves), images and videos in the format they were copied in.
    /// - Returns: `false` if stored media is missing.
    @discardableResult
    func copy(_ content: ClipContent) -> Bool {
        var items: [NSPasteboardItem] = []
        switch content {
        case .text(let text):
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            items = [item]
        case .files(let urls):
            items = urls.map { url in
                let item = NSPasteboardItem()
                item.setString(url.absoluteString, forType: .fileURL)
                return item
            }
        case .media(let asset):
            guard let data = try? Data(contentsOf: store.media.url(for: asset)) else { return false }
            let item = NSPasteboardItem()
            item.setData(data, forType: NSPasteboard.PasteboardType(asset.typeIdentifier))
            if asset.type?.conforms(to: .image) == true, asset.typeIdentifier != NSPasteboard.PasteboardType.tiff.rawValue {
                // Some older apps only read TIFF. Convert only if one asks.
                let provider = TIFFProvider(imageData: data) { [weak self] in self?.tiffProvider = nil }
                item.setDataProvider(provider, forTypes: [.tiff])
                tiffProvider = provider
            }
            items = [item]
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            items.first?.setString(bundleID, forType: PasteboardMonitor.sourceType)
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        monitor.skipCurrentChange()
        return true
    }

    /// Synthesizes ⌘V. Needs Accessibility access.
    /// - Returns: `false` if the app isn't trusted to post keyboard events.
    private static func sendPasteKeystroke() -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep the user's physical keyboard from interfering while the synthetic keystroke is delivered.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let key = KeyboardLayout.keyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V)
        // 0x08 is the left-Command device bit; some apps only honor ⌘ when it's set.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown)
            event?.flags = flags
            event?.post(tap: .cgSessionEventTap)
        }
        return true
    }
}

/// Supplies a TIFF version of an image only when an app asks the clipboard for one.
private final class TIFFProvider: NSObject, NSPasteboardItemDataProvider {
    private let imageData: Data
    private let onFinished: () -> Void

    init(imageData: Data, onFinished: @escaping () -> Void) {
        self.imageData = imageData
        self.onFinished = onFinished
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if let tiff = NSImage(data: imageData)?.tiffRepresentation {
            item.setData(tiff, forType: type)
        }
    }

    /// Something else was copied, so the image data can be released.
    func pasteboardFinishedWithDataProvider(_ pasteboard: NSPasteboard) {
        onFinished()
    }
}
