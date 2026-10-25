import Carbon.HIToolbox
import CoreGraphics

/// Maps between virtual key codes and the characters they type in the user's keyboard layout.
enum KeyboardLayout {
    static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥", kVK_Space: "Space",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static func displayName(for keyCode: UInt16) -> String {
        specialKeyNames[Int(keyCode)] ?? character(for: keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    /// The character a key types in the current layout, ignoring modifiers.
    static func character(for keyCode: UInt16) -> String? {
        withCurrentLayout { translate(keyCode, in: $0) }
    }

    /// The key that types `character` in the current layout, so a synthesized ⌘V hits the right
    /// key on Dvorak, AZERTY and friends.
    static func keyCode(typing character: String) -> CGKeyCode? {
        withCurrentLayout { layout in
            (0..<128).first { translate(UInt16($0), in: layout)?.lowercased() == character }.map { CGKeyCode($0) }
        }
    }

    private static func withCurrentLayout<T>(_ body: (UnsafePointer<UCKeyboardLayout>) -> T?) -> T? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1, body)
    }

    private static func translate(_ keyCode: UInt16, in layout: UnsafePointer<UCKeyboardLayout>) -> String? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
