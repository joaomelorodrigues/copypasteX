import Foundation
import Observation

/// User settings, persisted in `UserDefaults`.
@Observable
final class Preferences {
    enum Key: String, CaseIterable {
        case hotKey
        case historySize
        case menuItemCount
        case menuItemLength
        case stickyBezel
        case wrapAround
        case showSourceApp
        case pasteOnSelect
        case moveToTopOnPaste
        case removeDuplicates
        case saveHistory
        case ignoreWhitespace
        case ignoredApps
        case hasLaunchedBefore
    }

    /// Apps whose clipboard content is never recorded, on top of anything marked concealed.
    static let defaultIgnoredApps = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
    ]

    /// Called after a setting changes so the app can react (re-register the hotkey, trim history, …).
    @ObservationIgnored var didChange: ((Key) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    var hotKey: KeyCombo { didSet { save(hotKey.dictionary, .hotKey) } }
    var historySize: Int { didSet { save(historySize, .historySize) } }
    var menuItemCount: Int { didSet { save(menuItemCount, .menuItemCount) } }
    var menuItemLength: Int { didSet { save(menuItemLength, .menuItemLength) } }
    var stickyBezel: Bool { didSet { save(stickyBezel, .stickyBezel) } }
    var wrapAround: Bool { didSet { save(wrapAround, .wrapAround) } }
    var showSourceApp: Bool { didSet { save(showSourceApp, .showSourceApp) } }
    var pasteOnSelect: Bool { didSet { save(pasteOnSelect, .pasteOnSelect) } }
    var moveToTopOnPaste: Bool { didSet { save(moveToTopOnPaste, .moveToTopOnPaste) } }
    var removeDuplicates: Bool { didSet { save(removeDuplicates, .removeDuplicates) } }
    var saveHistory: Bool { didSet { save(saveHistory, .saveHistory) } }
    var ignoreWhitespace: Bool { didSet { save(ignoreWhitespace, .ignoreWhitespace) } }
    var ignoredApps: [String] { didSet { save(ignoredApps, .ignoredApps) } }
    var hasLaunchedBefore: Bool { didSet { save(hasLaunchedBefore, .hasLaunchedBefore) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.hotKey.rawValue: KeyCombo.default.dictionary,
            Key.historySize.rawValue: 100,
            Key.menuItemCount.rawValue: 10,
            Key.menuItemLength.rawValue: 50,
            Key.stickyBezel.rawValue: true,
            Key.wrapAround.rawValue: false,
            Key.showSourceApp.rawValue: true,
            Key.pasteOnSelect.rawValue: true,
            Key.moveToTopOnPaste.rawValue: true,
            Key.removeDuplicates.rawValue: true,
            Key.saveHistory.rawValue: true,
            Key.ignoreWhitespace.rawValue: true,
            Key.ignoredApps.rawValue: Self.defaultIgnoredApps,
            Key.hasLaunchedBefore.rawValue: false,
        ])

        hotKey = KeyCombo(dictionary: defaults.dictionary(forKey: Key.hotKey.rawValue)) ?? .default
        historySize = defaults.integer(forKey: Key.historySize.rawValue)
        menuItemCount = defaults.integer(forKey: Key.menuItemCount.rawValue)
        menuItemLength = defaults.integer(forKey: Key.menuItemLength.rawValue)
        stickyBezel = defaults.bool(forKey: Key.stickyBezel.rawValue)
        wrapAround = defaults.bool(forKey: Key.wrapAround.rawValue)
        showSourceApp = defaults.bool(forKey: Key.showSourceApp.rawValue)
        pasteOnSelect = defaults.bool(forKey: Key.pasteOnSelect.rawValue)
        moveToTopOnPaste = defaults.bool(forKey: Key.moveToTopOnPaste.rawValue)
        removeDuplicates = defaults.bool(forKey: Key.removeDuplicates.rawValue)
        saveHistory = defaults.bool(forKey: Key.saveHistory.rawValue)
        ignoreWhitespace = defaults.bool(forKey: Key.ignoreWhitespace.rawValue)
        ignoredApps = defaults.stringArray(forKey: Key.ignoredApps.rawValue) ?? Self.defaultIgnoredApps
        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore.rawValue)
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
        didChange?(key)
    }
}
