import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press the new shortcut. Escape cancels; Delete restores the default.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    /// Called with `true` when recording starts, so the current global shortcut can be released.
    var onRecordingChange: (Bool) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            Text(isRecording ? "Type shortcut…" : combo.displayString)
                .monospacedDigit()
                .frame(minWidth: 110)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
            case kVK_Delete, kVK_ForwardDelete:
                combo = .default
                stop()
            default:
                if let newCombo = KeyCombo(event: event) {
                    combo = newCombo
                    stop()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        guard isRecording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        onRecordingChange(false)
    }
}
