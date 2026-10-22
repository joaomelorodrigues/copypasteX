import AppKit
import Observation
import SwiftUI

enum SettingsTab: Hashable {
    case general
    case history
    case permissions
    case about
}

@Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
}

/// Hosts the SwiftUI settings in a plain window. FlycutX has no Dock icon, so the window
/// activates the app when shown. The window is released when closed, so its views take no
/// memory while you aren't looking at them.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let navigation = SettingsNavigation()
    private let makeView: (SettingsNavigation) -> SettingsView
    private var window: NSWindow?

    init(makeView: @escaping (SettingsNavigation) -> SettingsView) {
        self.makeView = makeView
    }

    func show(_ tab: SettingsTab = .general) {
        navigation.tab = tab
        let window = window ?? makeWindow()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: makeView(navigation)))
        window.title = "FlycutX Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}
