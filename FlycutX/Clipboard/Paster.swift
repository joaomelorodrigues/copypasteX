import AppKit
import Carbon.HIToolbox
import FlycutCore

/// Puts clippings back on the pasteboard and, when asked, pastes them into the frontmost app.
final class Paster {
    private let store: ClipboardStore
    private let prefs: Preferences
    private let monitor: PasteboardMonitor
    private var didPromptForAccessibility = false

    init(store: ClipboardStore, prefs: Preferences, monitor: PasteboardMonitor) {
        self.store = store
        self.prefs = prefs
        self.monitor = monitor
    }

    /// Copies `clipping` and, if `paste` is true, sends ⌘V to the frontmost app.
    func use(_ clipping: Clipping, from kind: StoreKind, paste: Bool) {
        copy(clipping.text)
        switch kind {
        case .history where prefs.moveToTopOnPaste:
            store.moveToTop(clipping.id, in: .history)
        case .favorites:
            // A favorite on the clipboard is now the most recent clipping too.
            store.record(Clipping(text: clipping.text, sourceAppName: clipping.sourceAppName, sourceBundleID: clipping.sourceBundleID))
        default:
            break
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

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if let bundleID = Bundle.main.bundleIdentifier {
            pasteboard.setString(bundleID, forType: PasteboardMonitor.sourceType)
        }
        monitor.skipCurrentChange()
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
