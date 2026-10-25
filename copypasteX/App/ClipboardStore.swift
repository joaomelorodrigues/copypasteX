import CopypasteCore
import Foundation
import Observation
import os

enum StoreKind {
    case history
    case favorites

    var other: StoreKind { self == .history ? .favorites : .history }
}

/// The clipboard history and favorites. Changes are saved to disk shortly after they happen, off
/// the main thread, so bursts of copying turn into a single write.
@Observable
final class ClipboardStore {
    static let favoritesCapacity = 1000
    static let defaultFileURL = URL.applicationSupportDirectory.appending(path: "copypasteX/history.json")

    private(set) var history: ClipList
    private(set) var favorites: ClipList
    /// Where copied image and video data is kept, next to the history file.
    @ObservationIgnored let media: MediaLibrary

    @ObservationIgnored private let prefs: Preferences
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let writer = DispatchQueue(label: "copypasteX.history-writer", qos: .utility)
    @ObservationIgnored private let log = Logger(subsystem: "copypasteX", category: "store")

    init(prefs: Preferences, fileURL: URL = ClipboardStore.defaultFileURL) {
        self.prefs = prefs
        self.fileURL = fileURL
        media = MediaLibrary(folder: fileURL.deletingLastPathComponent().appending(path: "Media"))

        var snapshot: HistorySnapshot?
        do {
            snapshot = try HistoryFile.load(from: fileURL)
        } catch {
            log.error("Couldn't read history: \(error.localizedDescription, privacy: .public)")
        }
        history = ClipList(items: prefs.saveHistory ? snapshot?.clippings ?? [] : [], capacity: prefs.historySize)
        favorites = ClipList(items: snapshot?.favorites ?? [], capacity: Self.favoritesCapacity)

        // Media left over from history that wasn't kept (or a crash) is removed at launch.
        let media = media, keep = referencedMedia
        writer.async { Self.removeUnusedMedia(in: media, keeping: keep) }
    }

    subscript(kind: StoreKind) -> ClipList {
        kind == .history ? history : favorites
    }

    /// - Parameter mediaData: The image or video data, for media clippings.
    func record(_ clipping: Clipping, mediaData: Data? = nil) {
        if let mediaData, let asset = clipping.mediaAsset {
            let media = media
            writer.async {
                do {
                    try media.write(mediaData, for: asset)
                } catch {
                    Logger(subsystem: "copypasteX", category: "store").error("Couldn't store media: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        history.insert(clipping, removingDuplicates: prefs.removeDuplicates)
        scheduleSave()
    }

    func remove(_ id: UUID, from kind: StoreKind) {
        modify(kind) { $0.remove(id: id) }
    }

    func moveToTop(_ id: UUID, in kind: StoreKind) {
        modify(kind) { $0.moveToTop(id: id) }
    }

    /// Moves a clipping between the history and the favorites.
    func toggleFavorite(_ id: UUID, from kind: StoreKind) {
        var source = self[kind]
        guard let clipping = source.remove(id: id) else { return }
        var destination = self[kind.other]
        destination.insert(clipping, removingDuplicates: true)
        modify(kind) { $0 = source }
        modify(kind.other) { $0 = destination }
    }

    func clear(_ kind: StoreKind) {
        modify(kind) { $0.removeAll() }
    }

    /// Adds clippings from another source (e.g. classic Flycut) below the existing ones.
    func importSnapshot(_ snapshot: HistorySnapshot) -> (clippings: Int, favorites: Int) {
        let addedClippings = history.append(contentsOf: snapshot.clippings)
        let addedFavorites = favorites.append(contentsOf: snapshot.favorites)
        scheduleSave()
        return (addedClippings, addedFavorites)
    }

    func historySizeDidChange() {
        history.capacity = prefs.historySize
        scheduleSave()
    }

    func saveHistoryDidChange() {
        scheduleSave()
    }

    /// Writes pending changes immediately. Call before the app quits. Media belonging to history
    /// that isn't kept after quitting is deleted now.
    func saveNow() {
        pendingSave?.cancel()
        let snapshot = snapshot, url = fileURL, media = media
        let keep = Set((snapshot.clippings + snapshot.favorites).compactMap { $0.mediaAsset?.fileName })
        writer.sync {
            Self.write(snapshot, to: url)
            Self.removeUnusedMedia(in: media, keeping: keep)
        }
    }

    /// Media for the media clippings still in memory, saved or not.
    private var referencedMedia: Set<String> {
        history.mediaFileNames.union(favorites.mediaFileNames)
    }

    private func modify(_ kind: StoreKind, _ change: (inout ClipList) -> Void) {
        switch kind {
        case .history: change(&history)
        case .favorites: change(&favorites)
        }
        scheduleSave()
    }

    /// History is only written when the user wants it kept; favorites always are.
    private var snapshot: HistorySnapshot {
        HistorySnapshot(clippings: prefs.saveHistory ? history.items : [], favorites: favorites.items)
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard let self else { return }
            let snapshot = snapshot, url = fileURL, media = media, keep = referencedMedia
            writer.async {
                Self.write(snapshot, to: url)
                Self.removeUnusedMedia(in: media, keeping: keep)
            }
        }
    }

    private nonisolated static func removeUnusedMedia(in media: MediaLibrary, keeping keep: Set<String>) {
        do {
            try media.removeFiles(notIn: keep)
        } catch {
            Logger(subsystem: "copypasteX", category: "store").error("Couldn't clean up media: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func write(_ snapshot: HistorySnapshot, to url: URL) {
        do {
            if snapshot.clippings.isEmpty && snapshot.favorites.isEmpty {
                try HistoryFile.delete(at: url)
            } else {
                try HistoryFile.save(snapshot, to: url)
            }
        } catch {
            Logger(subsystem: "copypasteX", category: "store").error("Couldn't save history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
