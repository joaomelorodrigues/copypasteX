import AppKit
import Carbon.HIToolbox
import CopypasteCore
import Observation
import SwiftUI

/// What the bezel shows. Rows are a snapshot of the current list, filtered by the search query.
@Observable
final class BezelModel {
    var kind: StoreKind = .history
    var rows: [Clipping] = []
    var cursor = ListCursor()
    var totalCount = 0
    var query = ""
    var showSourceApp = true
    var returnPastes = true

    var selected: Clipping? {
        rows.indices.contains(cursor.index) ? rows[cursor.index] : nil
    }
}

/// Shows the bezel and turns key presses into navigation and actions.
///
/// Typing goes straight into a real text field, so accents, dead keys and input methods work.
/// Navigation keys and ⌘ shortcuts are intercepted before the field sees them.
final class BezelController: NSObject, NSTextFieldDelegate {
    let model = BezelModel()
    var openSettings: () -> Void = {}

    private let store: ClipboardStore
    private let prefs: Preferences
    private let paster: Paster
    private let searchField = NSTextField()
    private var panel: BezelPanel?

    /// When true, releasing the shortcut's modifier keys doesn't paste.
    private var isSticky = true

    private static let digitKeys: [Int: Int] = [
        kVK_ANSI_1: 0, kVK_ANSI_2: 1, kVK_ANSI_3: 2, kVK_ANSI_4: 3, kVK_ANSI_5: 4,
        kVK_ANSI_6: 5, kVK_ANSI_7: 6, kVK_ANSI_8: 7, kVK_ANSI_9: 8, kVK_ANSI_0: 9,
    ]

    init(store: ClipboardStore, prefs: Preferences, paster: Paster) {
        self.store = store
        self.prefs = prefs
        self.paster = paster
        super.init()
        configureSearchField()
    }

    var isVisible: Bool { panel?.isVisible == true }

    /// Pressing the shortcut again while the bezel is open steps to the next clipping.
    func hotKeyPressed() {
        if isVisible {
            model.cursor.step(1)
        } else {
            show()
        }
    }

    func show(_ kind: StoreKind = .history, searching: Bool = false) {
        model.kind = kind
        model.showSourceApp = prefs.showSourceApp
        model.returnPastes = prefs.pasteOnSelect
        setQuery("")

        // Without the shortcut's modifiers held there's nothing to release, so stay open.
        let shortcutModifiers = prefs.hotKey.modifierFlags.subtracting(.shift)
        let modifiersHeld = !NSEvent.modifierFlags.intersection(shortcutModifiers).isEmpty
        isSticky = prefs.stickyBezel || searching || shortcutModifiers.isEmpty || !modifiersHeld

        let panel = panel ?? makePanel()
        panel.setFrameOrigin(origin(for: panel.frame.size))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        // On first show, SwiftUI hasn't put the field in the window yet; lay out before focusing.
        panel.contentView?.layoutSubtreeIfNeeded()
        focusSearchField()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - Actions

    private enum Commit { case paste, copy }

    private func commit(_ action: Commit) {
        guard let clipping = model.selected else {
            hide()
            return
        }
        let kind = model.kind
        hide()
        paster.use(clipping, from: kind, paste: action == .paste && prefs.pasteOnSelect)
    }

    func select(_ index: Int) {
        model.cursor.select(index)
    }

    func activate(_ index: Int) {
        if model.cursor.select(index) { commit(.paste) }
    }

    private func deleteSelected() {
        guard let clipping = model.selected else { return }
        store.remove(clipping.id, from: model.kind)
        reload(selecting: .index(model.cursor.index))
    }

    private func toggleFavorite() {
        guard let clipping = model.selected else { return }
        store.toggleFavorite(clipping.id, from: model.kind)
        reload(selecting: .index(model.cursor.index))
    }

    func toggleList() {
        model.kind = model.kind.other
        reload(selecting: .first)
    }

    private func saveSelected() {
        guard let clipping = model.selected else { return }
        hide()
        do {
            _ = try ClippingExport.saveToDesktop(clipping, media: store.media)
        } catch {
            NSSound.beep()
        }
    }

    // MARK: - Search

    private func configureSearchField() {
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: NSFont.systemFontSize)
        searchField.placeholderString = "Type to search"
        searchField.usesSingleLineMode = true
        searchField.cell?.isScrollable = true
        searchField.cell?.wraps = false
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        searchField.delegate = self
    }

    func controlTextDidChange(_ notification: Notification) {
        // Typing means the user is searching, so letting go of the shortcut keys shouldn't paste.
        isSticky = true
        model.query = searchField.stringValue
        reload(selecting: .first)
    }

    private func setQuery(_ query: String) {
        searchField.stringValue = query
        model.query = query
        reload(selecting: .first)
    }

    /// Clicking a row can move keyboard focus away from the field; put it back, caret at the end.
    private func focusSearchField() {
        guard let panel else { return }
        if let editor = searchField.currentEditor(), panel.firstResponder === editor { return }
        panel.makeFirstResponder(searchField)
        searchField.currentEditor()?.selectedRange = NSRange(location: searchField.stringValue.utf16.count, length: 0)
    }

    /// Sends an editing command (paste, select all, …) to the search field.
    private func editSearchField(_ action: Selector) {
        focusSearchField()
        panel?.firstResponder?.tryToPerform(action, with: nil)
    }

    // MARK: - Keyboard

    /// - Returns: `true` if the key was used here; `false` lets it reach the search field.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)

        switch Int(event.keyCode) {
        case kVK_DownArrow: command ? model.cursor.moveToEnd() : model.cursor.step(1)
        case kVK_UpArrow: command ? model.cursor.moveToStart() : model.cursor.step(-1)
        case kVK_PageDown: model.cursor.jump(10)
        case kVK_PageUp: model.cursor.jump(-10)
        case kVK_Home: model.cursor.moveToStart()
        case kVK_End: model.cursor.moveToEnd()
        // The main Return key and the keypad's Enter (also fn-Return on laptops) both paste.
        case kVK_Return, kVK_ANSI_KeypadEnter: commit(.paste)
        case kVK_Tab: toggleList()
        case kVK_Escape: model.query.isEmpty ? hide() : setQuery("")
        default:
            if command { return handleCommandKey(event) }
            focusSearchField()
            return false
        }
        return true
    }

    private func handleCommandKey(_ event: NSEvent) -> Bool {
        // Digits by key position, so ⌘1–⌘0 also work while Shift is held (non-sticky mode).
        if let digit = Self.digitKeys[Int(event.keyCode)] {
            if model.cursor.select(digit) { commit(.paste) }
            return true
        }
        if [kVK_Delete, kVK_ForwardDelete].contains(Int(event.keyCode)) {
            deleteSelected()
            return true
        }
        // Letters by character, so they follow the keyboard layout.
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c": commit(.copy)
        case "d": toggleFavorite()
        case "s": saveSelected()
        case ",":
            hide()
            openSettings()
        case "f":
            isSticky = true
            focusSearchField()
        case "v": editSearchField(#selector(NSText.paste(_:)))
        case "a": editSearchField(#selector(NSText.selectAll(_:)))
        case "x": editSearchField(#selector(NSText.cut(_:)))
        default:
            // Swallow other shortcuts (⌘Q, ⌘W…) so they don't reach copypasteX's own menu.
            break
        }
        return true
    }

    /// In non-sticky mode, letting go of the shortcut's modifiers pastes, like classic Flycut.
    private func handleModifiersChanged(_ event: NSEvent) {
        guard !isSticky, isVisible else { return }
        if event.modifierFlags.intersection(prefs.hotKey.modifierFlags.subtracting(.shift)).isEmpty {
            commit(.paste)
        }
    }

    private func handleMouseUp() {
        // Using the mouse means the user isn't holding the shortcut to paste on release.
        isSticky = true
        focusSearchField()
    }

    // MARK: - Helpers

    private enum Selection {
        case first
        case index(Int)
    }

    private func reload(selecting selection: Selection) {
        let list = store[model.kind]
        model.rows = list.filtered(by: model.query)
        model.totalCount = list.count
        model.cursor.wraps = prefs.wrapAround
        model.cursor.count = model.rows.count
        switch selection {
        case .first:
            model.cursor.moveToStart()
        case .index(let index):
            if !model.cursor.select(index) { model.cursor.moveToEnd() }
        }
    }

    /// Centered on the screen with the mouse pointer, a little above the middle like Spotlight.
    private func origin(for size: CGSize) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return .zero }
        return CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2 + frame.height * 0.08)
    }

    private func makePanel() -> BezelPanel {
        let panel = BezelPanel(size: BezelView.windowSize)
        let view = BezelView(
            model: model,
            searchField: searchField,
            media: store.media,
            onSelect: { [unowned self] in select($0) },
            onActivate: { [unowned self] in activate($0) },
            onToggleList: { [unowned self] in toggleList() }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onKeyDown = { [unowned self] in handleKeyDown($0) }
        panel.onModifiersChanged = { [unowned self] in handleModifiersChanged($0) }
        panel.onMouseUp = { [unowned self] in handleMouseUp() }
        panel.onResignKey = { [unowned self] in hide() }
        self.panel = panel
        return panel
    }
}
