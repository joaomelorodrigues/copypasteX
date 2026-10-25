import Carbon.HIToolbox
import Observation

/// Registers the app's global shortcut. Carbon hot keys don't need Accessibility access and
/// fire no matter which app is active.
@Observable
final class HotKeyCenter {
    /// Set when the system refuses the shortcut, usually because another app already uses it.
    private(set) var registrationFailed = false

    @ObservationIgnored var onPress: (() -> Void)?
    @ObservationIgnored private var combo: KeyCombo?
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?

    func register(_ combo: KeyCombo) {
        self.combo = combo
        unregisterHotKey()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x4350_5358), id: 1) // 'CPSX'
        // macOS lets several apps register the same shortcut and then triggers all of them.
        // Exclusive registration fails if another app already claimed it exclusively, and keeps
        // apps that come later from claiming ours.
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive), &hotKeyRef
        )
        registrationFailed = status != noErr
    }

    /// Temporarily releases the shortcut, e.g. while the user records a new one.
    func suspend() {
        unregisterHotKey()
    }

    func resume() {
        if let combo { register(combo) }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.onPress?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
