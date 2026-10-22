import AppKit
import FlycutCore

/// The menu bar icon and its menu. The menu is rebuilt each time it opens, so nothing is kept
/// up to date in the background.
final class StatusMenuController: NSObject, NSMenuDelegate {
    var showBezel: (StoreKind, _ searching: Bool) -> Void = { _, _ in }
    var openSettings: (SettingsTab) -> Void = { _ in }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let store: ClipboardStore
    private let prefs: Preferences
    private let monitor: PasteboardMonitor
    private let paster: Paster

    init(store: ClipboardStore, prefs: Preferences, monitor: PasteboardMonitor, paster: Paster) {
        self.store = store
        self.prefs = prefs
        self.monitor = monitor
        self.paster = paster
        super.init()

        menu.delegate = self
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "FlycutX")
            button.toolTip = "FlycutX — Option-click to pause clipboard tracking"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            togglePause()
            return
        }
        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if monitor.isPaused {
            menu.addItem(disabledItem("Clipboard tracking is paused"))
            menu.addItem(.separator())
        }
        if Permissions.clipboardAccess == .denied {
            menu.addItem(item("Clipboard access is turned off…", #selector(openPermissions)))
            menu.addItem(.separator())
        }

        let recent = store.history.items.prefix(prefs.menuItemCount)
        if store.history.isEmpty {
            menu.addItem(disabledItem("No clippings yet"))
        } else {
            recent.forEach { menu.addItem(clippingItem($0, kind: .history)) }
        }

        if !store.favorites.isEmpty {
            menu.addItem(.separator())
            let favorites = NSMenu()
            store.favorites.items.prefix(30).forEach { favorites.addItem(clippingItem($0, kind: .favorites)) }
            favorites.addItem(.separator())
            favorites.addItem(item("Show All Favorites…", #selector(showFavorites)))
            let favoritesItem = NSMenuItem(title: "Favorites", action: nil, keyEquivalent: "")
            favoritesItem.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
            favoritesItem.submenu = favorites
            menu.addItem(favoritesItem)
        }

        menu.addItem(.separator())
        let search = item("Search History…", #selector(showSearch))
        search.keyEquivalent = prefs.hotKey.keyEquivalent
        search.keyEquivalentModifierMask = prefs.hotKey.modifierFlags
        menu.addItem(search)
        let pause = item("Pause Clipboard Tracking", #selector(togglePause))
        pause.state = monitor.isPaused ? .on : .off
        menu.addItem(pause)
        let merge = item("Merge All Clippings", #selector(mergeAll))
        merge.toolTip = "Combine all clippings, oldest first, into one new clipping on the clipboard."
        merge.isEnabled = store.history.count > 1
        menu.addItem(merge)
        let clear = item("Clear History…", #selector(clearHistory))
        clear.isEnabled = !store.history.isEmpty
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        menu.addItem(item("Quit FlycutX", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    // MARK: - Actions

    @objc private func clippingChosen(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        let kind: StoreKind = sender.tag == 1 ? .favorites : .history
        guard let clipping = store[kind][id] else { return }
        paster.use(clipping, from: kind, paste: prefs.pasteOnSelect)
    }

    @objc private func togglePause() {
        monitor.isPaused.toggle()
        statusItem.button?.appearsDisabled = monitor.isPaused
    }

    @objc private func mergeAll() {
        let merged = Clipping(text: store.history.joinedText())
        store.record(merged)
        paster.copy(merged.text)
    }

    @objc private func clearHistory() {
        if Alerts.confirmClearHistory(count: store.history.count) {
            store.clear(.history)
        }
    }

    @objc private func showSearch() { showBezel(.history, true) }
    @objc private func showFavorites() { showBezel(.favorites, false) }
    @objc private func showSettings() { openSettings(.general) }
    @objc private func openPermissions() { openSettings(.permissions) }

    // MARK: - Items

    private func clippingItem(_ clipping: Clipping, kind: StoreKind) -> NSMenuItem {
        let item = item(clipping.title(maxLength: prefs.menuItemLength), #selector(clippingChosen(_:)))
        item.representedObject = clipping.id
        item.tag = kind == .favorites ? 1 : 0
        item.toolTip = String(clipping.text.prefix(600))
        if prefs.showSourceApp, let bundleID = clipping.sourceBundleID, let icon = AppInfo.icon(for: bundleID) {
            let image = icon.copy() as? NSImage
            image?.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        return item
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
