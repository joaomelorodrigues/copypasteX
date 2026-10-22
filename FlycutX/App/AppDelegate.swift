import AppKit
import FlycutCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private let monitor = PasteboardMonitor()
    private let hotKeys = HotKeyCenter()
    private lazy var store = ClipboardStore(prefs: prefs)
    private lazy var paster = Paster(store: store, prefs: prefs, monitor: monitor)
    private lazy var bezel = BezelController(store: store, prefs: prefs, paster: paster)
    private lazy var settings = SettingsWindowController { [prefs, store, hotKeys] navigation in
        SettingsView(prefs: prefs, store: store, hotKeys: hotKeys, navigation: navigation)
    }
    private var statusMenu: StatusMenuController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        monitor.policy = { [prefs] in
            CapturePolicy(ignoredBundleIDs: Set(prefs.ignoredApps), ignoresWhitespaceOnly: prefs.ignoreWhitespace)
        }
        monitor.onCapture = { [store] in store.record($0) }
        monitor.start()

        bezel.openSettings = { [settings] in settings.show() }
        hotKeys.onPress = { [bezel] in bezel.hotKeyPressed() }
        hotKeys.register(prefs.hotKey)

        let statusMenu = StatusMenuController(store: store, prefs: prefs, monitor: monitor, paster: paster)
        statusMenu.showBezel = { [bezel] kind, searching in bezel.show(kind, searching: searching) }
        statusMenu.openSettings = { [settings] tab in settings.show(tab) }
        self.statusMenu = statusMenu

        prefs.didChange = { [weak self] key in self?.preferenceDidChange(key) }

        if !prefs.hasLaunchedBefore {
            prefs.hasLaunchedBefore = true
            FlycutImporter.offerImportIfAvailable(into: store)
            settings.show(.permissions)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    /// Opening the app again (from Finder or Spotlight) shows its settings, since it has no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    private func preferenceDidChange(_ key: Preferences.Key) {
        switch key {
        case .hotKey: hotKeys.register(prefs.hotKey)
        case .historySize: store.historySizeDidChange()
        case .saveHistory: store.saveHistoryDidChange()
        default: break
        }
    }

    @objc private func showSettings(_ sender: Any?) {
        settings.show()
    }

    /// Never visible (no Dock icon), but gives the settings window ⌘W, ⌘Q and the standard edit commands.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About FlycutX", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FlycutX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for (title, submenu) in [("FlycutX", appMenu), ("Edit", editMenu), ("Window", windowMenu)] {
            mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
        }
        return mainMenu
    }
}
