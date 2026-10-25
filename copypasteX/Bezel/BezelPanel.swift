import AppKit

/// A floating panel that takes keyboard focus without activating copypasteX, so the app the user
/// is working in stays frontmost and receives the paste.
final class BezelPanel: NSPanel {
    /// Sees every key press before the focused view does. Returns whether the key was used;
    /// unused keys continue to the search field.
    var onKeyDown: (NSEvent) -> Bool = { _ in false }
    var onModifiersChanged: (NSEvent) -> Void = { _ in }
    var onMouseUp: () -> Void = {}
    var onResignKey: () -> Void = {}

    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        // The bezel view draws its own shadow; a window shadow would trace the translucent glass.
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// ⌘ shortcuts arrive here before the app's menu gets a chance at them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        (isKeyWindow && onKeyDown(event)) || super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if onKeyDown(event) { return }
        case .flagsChanged:
            onModifiersChanged(event)
        case .leftMouseUp:
            super.sendEvent(event)
            onMouseUp()
            return
        default:
            break
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }
}
