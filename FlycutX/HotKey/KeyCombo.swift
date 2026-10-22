import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code plus Carbon modifier flags.
struct KeyCombo: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey | shiftKey))

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// A shortcut from a key press. A plain key (or Shift + key) is rejected, since it would
    /// swallow normal typing, except for function keys.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard Self.functionKeys.contains(Int(event.keyCode)) || !flags.subtracting(.shift).isEmpty else {
            return nil
        }
        var modifiers = 0
        if flags.contains(.command) { modifiers |= cmdKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: UInt32(modifiers))
    }

    init?(dictionary: [String: Any]?) {
        guard let keyCode = dictionary?["keyCode"] as? Int, let modifiers = dictionary?["modifiers"] as? Int else {
            return nil
        }
        self.init(keyCode: UInt32(keyCode), carbonModifiers: UInt32(modifiers))
    }

    var dictionary: [String: Int] {
        ["keyCode": Int(keyCode), "modifiers": Int(carbonModifiers)]
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    /// The key's character, for use as an `NSMenuItem` key equivalent. Empty for special keys.
    var keyEquivalent: String {
        KeyboardLayout.specialKeyNames[Int(keyCode)] == nil
            ? KeyboardLayout.character(for: UInt16(keyCode))?.lowercased() ?? ""
            : ""
    }

    /// For example "⇧⌘V", with modifiers in the standard macOS order.
    var displayString: String {
        let flags = modifierFlags
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result + KeyboardLayout.displayName(for: UInt16(keyCode))
    }
}
