import Combine
import Foundation

/// How Recent Files keeps the right to re-read a file after a relaunch. The
/// sandbox forgets a picked file's permission when the app quits, so a bare
/// path can't be opened again; a security-scoped bookmark can. Injectable so
/// unit tests run without the sandbox.
struct FileBookmarks {
    var make: (URL) -> Data?
    var resolve: (Data) -> (url: URL, isStale: Bool)?
    var startAccess: (URL) -> Bool
    var stopAccess: (URL) -> Void

    /// Read-only, to match `files.user-selected.read-only`; needs
    /// `files.bookmarks.app-scope` in the entitlements.
    static let securityScoped = FileBookmarks(
        make: { url in
            try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                  includingResourceValuesForKeys: nil, relativeTo: nil)
        },
        // Resolved on the main thread from a row click. Without `.withoutMounting`
        // a file on a disconnected share would try to mount it and freeze the
        // popover until the network times out; this way it fails fast and the
        // row shows the existing "Couldn't read file".
        resolve: { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale) else { return nil }
            return (url, isStale)
        },
        startAccess: { $0.startAccessingSecurityScopedResource() },
        stopAccess: { $0.stopAccessingSecurityScopedResource() }
    )
}

/// Persists the recently-hashed files across launches via UserDefaults, each
/// with a bookmark so it can still be read after a restart.
/// Capped at `maxItems`; most-recent-first; deduplicates on add (moving an
/// existing entry to the top rather than inserting a duplicate).
final class FileHistoryStore: ObservableObject {
    struct Entry: Equatable {
        var path: String
        var bookmark: Data?
    }

    @Published private(set) var entries: [Entry] = []

    var paths: [String] { entries.map(\.path) }

    private let key = "HashStack.fileHistory.v2"
    /// Paths only, written before bookmarks. Read once to carry the list
    /// over and otherwise left alone, so the previous build still finds its
    /// own list; only `clear()` removes it.
    private let legacyKey = "HashStack.fileHistory.v1"
    private let maxItems = 10

    private let defaults: UserDefaults
    private let bookmarks: FileBookmarks
    /// The file `open(_:)` last gained access to, held until the next pick:
    /// changing the algorithm re-reads the same file, so access can't end
    /// when one hash does.
    private var held: URL?

    /// `defaults` is injectable so unit tests use a throwaway suite instead of
    /// the user's real history. The app always uses `.standard`.
    init(defaults: UserDefaults = .standard, bookmarks: FileBookmarks = .securityScoped) {
        self.defaults = defaults
        self.bookmarks = bookmarks
        load()
    }

    /// Records `url` as the most-recent item. If `url` already exists
    /// in history, it's moved to the top rather than duplicated. Call it only
    /// while `url` is readable: the bookmark is made now.
    func add(_ url: URL) {
        let path = url.path
        guard !path.isEmpty else { return }
        // A failed bookmark keeps the one we had rather than losing it.
        let bookmark = bookmarks.make(url) ?? entries.first(where: { $0.path == path })?.bookmark
        entries.removeAll(where: { $0.path == path })
        entries.insert(Entry(path: path, bookmark: bookmark), at: 0)
        if entries.count > maxItems { entries = Array(entries.prefix(maxItems)) }
        save()
    }

    /// The URL to hash for the Recent Files row `path`, with sandbox access
    /// started and held until the next `open` or `releaseAccess()`. Falls back
    /// to the bare path when there's no bookmark or it no longer resolves; the
    /// hash then fails and the popover says the file couldn't be read.
    /// A file that moved is followed, and its row takes the new path.
    func open(_ path: String) -> URL {
        guard let i = entries.firstIndex(where: { $0.path == path }),
              let data = entries[i].bookmark,
              let resolved = bookmarks.resolve(data) else {
            releaseAccess()
            return URL(fileURLWithPath: path)
        }
        // Start before stopping, so re-opening the held file never drops it.
        let started = bookmarks.startAccess(resolved.url)
        releaseAccess()
        if started { held = resolved.url }
        let newPath = resolved.url.path
        if newPath != path {
            entries[i].path = newPath
            entries = entries.enumerated()
                .filter { $0.offset == i || $0.element.path != newPath }
                .map { $0.element }
            save()
        }
        // A stale bookmark still resolves; `add` replaces it once the hash succeeds.
        return resolved.url
    }

    /// Ends the access `open(_:)` started. Call when a file is picked or
    /// dropped instead, or when the held file fails to read.
    func releaseAccess() {
        if let url = held { bookmarks.stopAccess(url) }
        held = nil
    }

    /// Clear means gone: PRIVACY.md promises it, so the carried-over v1 path
    /// list is removed too rather than left in the preferences file.
    func clear() {
        entries = []
        save()
        defaults.removeObject(forKey: legacyKey)
    }

    private func load() {
        if let stored = defaults.array(forKey: key) as? [[String: Any]] {
            entries = stored.compactMap { item in
                guard let path = item["path"] as? String else { return nil }
                return Entry(path: path, bookmark: item["bookmark"] as? Data)
            }
        } else if let legacy = defaults.array(forKey: legacyKey) as? [String] {
            entries = legacy.map { Entry(path: $0, bookmark: nil) }
        }
    }

    private func save() {
        defaults.set(entries.map { entry -> [String: Any] in
            var item: [String: Any] = ["path": entry.path]
            if let bookmark = entry.bookmark { item["bookmark"] = bookmark }
            return item
        }, forKey: key)
    }
}
