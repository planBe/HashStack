import Combine
import Foundation

/// Persists the recently-hashed file paths across launches via UserDefaults.
/// Capped at `maxItems`; most-recent-first; deduplicates on add (moving an
/// existing entry to the top rather than inserting a duplicate).
final class FileHistoryStore: ObservableObject {
    @Published private(set) var paths: [String] = []

    private let key = "HashStack.fileHistory.v1"
    private let maxItems = 10

    init() {
        load()
    }

    /// Records `url`'s path as the most-recent item. If `url` already exists
    /// in history, it's moved to the top rather than duplicated.
    func add(_ url: URL) {
        let path = url.path
        guard !path.isEmpty else { return }
        paths.removeAll(where: { $0 == path })
        paths.insert(path, at: 0)
        if paths.count > maxItems { paths = Array(paths.prefix(maxItems)) }
        save()
    }

    func clear() {
        paths = []
        save()
    }

    private func load() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            paths = stored
        }
    }

    private func save() {
        UserDefaults.standard.set(paths, forKey: key)
    }
}
