import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var prefs: Preferences
    let store: ClipboardStore
    let hotKeys: HotKeyCenter
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralSettings(prefs: prefs, hotKeys: hotKeys)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            HistorySettings(prefs: prefs, store: store)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(SettingsTab.history)
            PermissionSettings()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 560, height: 540)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Bindable var prefs: Preferences
    let hotKeys: HotKeyCenter
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Open clipboard history") {
                    ShortcutRecorder(combo: $prefs.hotKey) { recording in
                        recording ? hotKeys.suspend() : hotKeys.resume()
                    }
                }
                if hotKeys.registrationFailed {
                    Label("This shortcut is already used by another app. Choose a different one.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                        }
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                ))
                if let launchError {
                    Text(launchError)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section("Bezel") {
                Toggle(isOn: $prefs.stickyBezel) {
                    Text("Sticky bezel")
                    Text("Keep the bezel open after you let go of the shortcut. When off, releasing the keys pastes the selected clipping, like classic Flycut.")
                }
                Toggle("Wrap around at the ends of the list", isOn: $prefs.wrapAround)
                Toggle("Show which app each clipping came from", isOn: $prefs.showSourceApp)
            }

            Section("Pasting") {
                Toggle(isOn: $prefs.pasteOnSelect) {
                    Text("Paste after choosing a clipping")
                    Text("When off, the clipping is only copied to the clipboard.")
                }
                Toggle("Move used clippings to the top", isOn: $prefs.moveToTopOnPaste)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

// MARK: - History

private struct HistorySettings: View {
    @Bindable var prefs: Preferences
    let store: ClipboardStore

    var body: some View {
        Form {
            Section {
                Stepper(value: $prefs.historySize, in: 10...5000, step: 10) {
                    Text("Remember \(prefs.historySize) clippings")
                }
                Toggle(isOn: $prefs.saveHistory) {
                    Text("Keep history after quitting")
                    Text("Saved only on this Mac, readable only by you. Favorites are always kept.")
                }
                Toggle("Move repeated copies to the top instead of keeping duplicates", isOn: $prefs.removeDuplicates)
                Toggle("Ignore clippings that are only whitespace", isOn: $prefs.ignoreWhitespace)
            }

            Section("Menu Bar") {
                Stepper(value: $prefs.menuItemCount, in: 0...50) {
                    Text("Show \(prefs.menuItemCount) recent clippings in the menu")
                }
                Stepper(value: $prefs.menuItemLength, in: 20...150, step: 5) {
                    Text("Shorten menu titles to \(prefs.menuItemLength) characters")
                }
            }

            Section {
                ForEach(prefs.ignoredApps, id: \.self) { bundleID in
                    HStack {
                        AppIcon(bundleID: bundleID, size: 18)
                        Text(AppInfo.name(for: bundleID) ?? bundleID)
                        Spacer()
                        Button {
                            prefs.ignoredApps.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Stop ignoring this app")
                    }
                }
                Button("Add App…", action: addIgnoredApps)
            } header: {
                Text("Ignored Apps")
            } footer: {
                Text("Nothing copied in these apps is recorded. Passwords and other content apps mark as concealed are always ignored.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Section {
                HStack {
                    Button("Import from Flycut…") { FlycutImporter.run(into: store) }
                    Spacer()
                    Button("Clear History…", role: .destructive) {
                        if Alerts.confirmClearHistory(count: store.history.count) {
                            store.clear(.history)
                        }
                    }
                    .disabled(store.history.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addIgnoredApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !prefs.ignoredApps.contains(bundleID) {
                prefs.ignoredApps.append(bundleID)
            }
        }
    }
}

// MARK: - Permissions

private struct PermissionSettings: View {
    @State private var accessibility = Permissions.isAccessibilityTrusted
    @State private var clipboard = Permissions.clipboardAccess

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Lets FlycutX press ⌘V for you after you pick a clipping. Without it, clippings are only copied and you paste them yourself.",
                    status: accessibility ? .granted : .missing
                ) {
                    Button("Open Settings…") {
                        Permissions.requestAccessibility()
                        Permissions.openAccessibilitySettings()
                    }
                }
            } footer: {
                Text("If FlycutX is already listed but pasting doesn't work, remove it from the list with − and add it again. This is needed after installing a new build.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            if #available(macOS 15.4, *) {
                Section {
                    PermissionRow(
                        title: "Paste from Other Apps",
                        detail: "macOS asks before apps read the clipboard in the background. Choose “Allow” for FlycutX in Privacy & Security ▸ Paste from Other Apps so it can record what you copy.",
                        status: clipboard == .allowed ? .granted : clipboard == .denied ? .missing : .prompt
                    ) {
                        Button("Open Settings…", action: Permissions.openClipboardSettings)
                    }
                } footer: {
                    Text("After changing this setting, quit and reopen FlycutX.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            // Permissions change in System Settings, which can't notify us; check while visible.
            while !Task.isCancelled {
                accessibility = Permissions.isAccessibilityTrusted
                clipboard = Permissions.clipboardAccess
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct PermissionRow<Action: View>: View {
    enum Status { case granted, prompt, missing }

    let title: String
    let detail: String
    let status: Status
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if status != .granted {
                    action.padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch status {
        case .granted: "checkmark.circle.fill"
        case .prompt: "questionmark.circle.fill"
        case .missing: "exclamationmark.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .granted: .green
        case .prompt: .orange
        case .missing: .red
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("FlycutX").font(.largeTitle.weight(.semibold))
            Text(version).foregroundStyle(.secondary)
            Text("A clean and simple clipboard manager for developers.\nA modern rewrite of Flycut, which grew out of Jumpcut.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("Original Flycut on GitHub", destination: URL(string: "https://github.com/TermiT/Flycut")!)
            Spacer()
            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
