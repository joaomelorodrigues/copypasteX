import AppKit

enum Alerts {
    static func confirmClearHistory(count: Int) -> Bool {
        confirm(
            "Clear clipboard history?",
            "This removes \(count) clipping\(count == 1 ? "" : "s"). Favorites are kept.",
            action: "Clear History",
            destructive: true
        )
    }

    static func confirm(_ title: String, _ message: String, action: String, cancel: String = "Cancel", destructive: Bool = false) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: action).hasDestructiveAction = destructive
        alert.addButton(withTitle: cancel)
        return run(alert) == .alertFirstButtonReturn
    }

    static func inform(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        run(alert)
    }

    /// FlycutX usually isn't the active app, so bring it forward or the alert hides behind other windows.
    @discardableResult
    private static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate()
        return alert.runModal()
    }
}
