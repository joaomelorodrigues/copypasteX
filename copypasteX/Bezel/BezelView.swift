import CopypasteCore
import SwiftUI

struct BezelView: View {
    static let size = CGSize(width: 720, height: 420)
    /// Transparent room around the bezel, so the glass's shadow and rim aren't cut off by the
    /// window's square edges. Clicks on fully transparent pixels pass through to the app behind.
    static let margin: CGFloat = 40
    static let windowSize = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)

    let model: BezelModel
    let searchField: NSTextField
    let media: MediaLibrary
    var onSelect: (Int) -> Void
    var onActivate: (Int) -> Void
    var onToggleList: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BezelHeader(model: model, searchField: searchField, onToggleList: onToggleList)
            Divider()
            if model.rows.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ClippingList(model: model, onSelect: onSelect, onActivate: onActivate)
                        .frame(width: 300)
                    Divider()
                    ClippingPreview(clipping: model.selected, media: media, showSourceApp: model.showSourceApp)
                }
            }
            Divider()
            KeyHints(returnPastes: model.returnPastes)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .bezelBackground(isFavorites: model.kind == .favorites)
        .padding(Self.margin)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.query.isEmpty {
            EmptyState(title: "No Results for “\(model.query)”", symbol: "magnifyingglass", message: "Check the spelling or try a different search.")
        } else if model.kind == .favorites {
            EmptyState(title: "No Favorites Yet", symbol: "star", message: "Press ⌘D on a clipping to keep it here for good.")
        } else {
            EmptyState(title: "Nothing Copied Yet", symbol: "list.clipboard", message: "Copy text, images or files and they'll show up here.")
        }
    }
}

private struct EmptyState: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

private struct BezelHeader: View {
    let model: BezelModel
    let searchField: NSTextField
    var onToggleList: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleList) {
                Label {
                    Text(model.kind == .favorites ? "Favorites" : "Clipboard")
                } icon: {
                    Image(systemName: model.kind == .favorites ? "star.fill" : "list.clipboard")
                        .foregroundStyle(model.kind == .favorites ? AnyShapeStyle(.yellow) : AnyShapeStyle(.primary))
                }
                .font(.headline)
            }
            .buttonStyle(.plain)
            .help("Switch between history and favorites (⇥)")

            Spacer()
            SearchCapsule(field: searchField, hasQuery: !model.query.isEmpty)

            Text(position)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var position: String {
        guard !model.rows.isEmpty else { return "0" }
        let base = "\(model.cursor.index + 1) of \(model.rows.count)"
        return model.rows.count == model.totalCount ? base : "\(base) (\(model.totalCount))"
    }
}

private struct SearchCapsule: View {
    let field: NSTextField
    let hasQuery: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            SearchFieldHost(field: field)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: 260)
        .background(.primary.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(hasQuery ? 0.8 : 0.35), lineWidth: 1.5))
    }
}

/// Embeds the controller's text field, which owns keyboard focus while the bezel is open.
private struct SearchFieldHost: NSViewRepresentable {
    let field: NSTextField

    func makeNSView(context: Context) -> NSTextField { field }
    func updateNSView(_ field: NSTextField, context: Context) {}
}

private struct ClippingList: View {
    let model: BezelModel
    var onSelect: (Int) -> Void
    var onActivate: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, clipping in
                        ClippingRow(
                            clipping: clipping,
                            shortcut: index > 9 ? nil : (index + 1) % 10,
                            isSelected: index == model.cursor.index,
                            showSourceApp: model.showSourceApp
                        )
                        .id(clipping.id)
                        .onTapGesture(count: 2) { onActivate(index) }
                        .simultaneousGesture(TapGesture().onEnded { onSelect(index) })
                    }
                }
                .padding(8)
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.cursor.index) {
                if let id = model.selected?.id { proxy.scrollTo(id) }
            }
            .onChange(of: model.rows.first?.id) { _, firstID in
                // A new search or list starts at the top.
                if let firstID { proxy.scrollTo(firstID, anchor: .top) }
            }
        }
    }
}

private struct ClippingRow: View {
    let clipping: Clipping
    let shortcut: Int?
    let isSelected: Bool
    let showSourceApp: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(shortcut.map(String.init) ?? "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.tertiary))
                .frame(width: 10)
            if showSourceApp {
                AppIcon(bundleID: clipping.sourceBundleID, size: 16)
            }
            if let symbol = clipping.kindSymbol {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
            Text(clipping.title(maxLength: 90))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct ClippingPreview: View {
    /// Rendering megabytes of text would stall the bezel; the full clipping is still pasted.
    private static let maxPreviewLength = 5_000

    let clipping: Clipping?
    let media: MediaLibrary
    let showSourceApp: Bool

    var body: some View {
        if let clipping {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch clipping.content {
                    case .text(let text):
                        ScrollView {
                            Text(previewText(text))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(14)
                        }
                    case .media(let asset):
                        ThumbnailPreview(url: media.url(for: asset), isVideo: asset.isVideo, caption: nil)
                    case .files(let urls) where urls.count == 1:
                        ThumbnailPreview(url: urls[0], isVideo: clipping.kindSymbol == "film", caption: urls[0].lastPathComponent)
                    case .files(let urls):
                        FileList(urls: urls)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(clipping.id)
                Divider()
                HStack(spacing: 6) {
                    if showSourceApp, clipping.sourceBundleID != nil {
                        AppIcon(bundleID: clipping.sourceBundleID, size: 14)
                    }
                    if let app = clipping.sourceAppName {
                        Text(app)
                        Text("·")
                    }
                    Text(clipping.date, format: .relative(presentation: .named))
                    Spacer()
                    Text(clipping.details)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        } else {
            Color.clear
        }
    }

    private func previewText(_ text: String) -> String {
        let head = text.prefix(Self.maxPreviewLength)
        return head.endIndex == text.endIndex ? text : String(head) + "\n…"
    }
}

/// A Quick Look thumbnail sized to the preview pane. Generated off the main thread and only
/// for the selected clipping.
private struct ThumbnailPreview: View {
    let url: URL
    let isVideo: Bool
    let caption: String?

    @State private var thumbnail: NSImage?
    @State private var isMissing = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    if isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.45))
                    }
                } else if isMissing {
                    Label("This file no longer exists", systemImage: "questionmark.folder")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let caption {
                Text(caption)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(18)
        .task(id: url) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                isMissing = true
                return
            }
            thumbnail = await Thumbnails.image(for: url, size: CGSize(width: 380, height: 280), scale: displayScale)
            isMissing = thumbnail == nil
        }
    }
}

/// Several copied files, listed with their Finder icons.
private struct FileList: View {
    private static let maxShown = 50

    let urls: [URL]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(urls.prefix(Self.maxShown), id: \.self) { url in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if urls.count > Self.maxShown {
                    Text("and \(urls.count - Self.maxShown) more")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}

private struct KeyHints: View {
    let returnPastes: Bool

    var body: some View {
        HStack(spacing: 14) {
            hint("↩", returnPastes ? "Paste" : "Copy")
            hint("⌘1–9", returnPastes ? "Paste #" : "Copy #")
            hint("⌘C", "Copy")
            hint("⌘D", "Favorite")
            hint("⌘⌫", "Delete")
            hint("⇥", "Switch list")
            Spacer()
            hint("esc", "Close")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(label)
        }
    }
}

private struct KeyCap: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct AppIcon: View {
    let bundleID: String?
    let size: CGFloat

    var body: some View {
        if let bundleID, let icon = AppInfo.icon(for: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: size * 0.75, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(width: size, height: size)
        }
    }
}

private extension View {
    /// Liquid Glass on macOS 26 and later; a HUD material before that. The window has no shadow
    /// of its own (it would be computed from the translucent pixels and look ragged), so the
    /// shadow comes from here: built into the glass, or drawn for the fallback.
    @ViewBuilder
    func bezelBackground(isFavorites: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        // Favorites get a yellow wash, like classic Flycut's tinted bezel.
        let tinted = background(isFavorites ? Color.yellow.opacity(0.14) : .clear, in: shape)
        if #available(macOS 26, *) {
            tinted.glassEffect(.regular, in: shape)
        } else {
            tinted
                .background { VisualEffectBackground().clipShape(shape) }
                .overlay(shape.strokeBorder(.white.opacity(0.12)))
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
