import AppKit
import ApplicationServices

/// The two privacy permissions a clipboard manager depends on.
enum Permissions {
    enum ClipboardAccess {
        /// Can read the clipboard in the background without asking.
        case allowed
        /// macOS will ask (or hasn't asked yet) each time the clipboard is read in the background.
        case ask
        /// The user denied access in System Settings.
        case denied
    }

    // MARK: Accessibility — needed to paste for the user

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that leads to Privacy & Security ▸ Accessibility.
    static func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    // MARK: Paste from Other Apps — needed to record what the user copies (macOS 15.4+)

    static var clipboardAccess: ClipboardAccess {
        guard #available(macOS 15.4, *) else { return .allowed }
        switch NSPasteboard.general.accessBehavior {
        case .alwaysAllow: return .allowed
        case .alwaysDeny: return .denied
        default: return .ask
        }
    }

    static func openClipboardSettings() {
        openPrivacyPane("Privacy_Pasteboard")
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
