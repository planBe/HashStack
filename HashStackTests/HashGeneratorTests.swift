import Foundation
import Testing

/// Pins HashStack's output to published test vectors (FIPS 180 / RFC 1321
/// "abc" and empty-string digests). If any of these drift, a user comparing
/// against a publisher's checksum would get a false ✗ DIFFER — the one thing
/// a hash tool must never do.
struct HashGeneratorTests {

    @Test("\"abc\" matches the published digest for every algorithm")
    func abcVectors() {
        #expect(HashGenerator.hash("abc", with: .md5) == "900150983cd24fb0d6963f7d28e17f72")
        #expect(HashGenerator.hash("abc", with: .sha1) == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect(HashGenerator.hash("abc", with: .sha256) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(HashGenerator.hash("abc", with: .sha512) == "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
    }

    @Test("Empty input matches the published empty-string digest")
    func emptyVectors() {
        #expect(HashGenerator.hash("", with: .md5) == "d41d8cd98f00b204e9800998ecf8427e")
        #expect(HashGenerator.hash("", with: .sha1) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        #expect(HashGenerator.hash("", with: .sha256) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("Text is hashed as UTF-8 (non-ASCII input)")
    func utf8() {
        // printf 'café' | shasum -a 256
        #expect(HashGenerator.hash("café", with: .sha256) == "850f7dc43910ff890f8879c0ed26fe697c93a067ad93a7d50f466a7028a9bf4e")
    }

    @Test("Streamed file hashing equals one-shot hashing across chunk boundaries",
          arguments: [0, 1, 1024 * 1024 - 1, 1024 * 1024, 1024 * 1024 + 1, 2_621_440])
    func fileMatchesData(size: Int) throws {
        var bytes = [UInt8](repeating: 0, count: size)
        for i in 0..<size { bytes[i] = UInt8(truncatingIfNeeded: i &* 31 &+ 7) }
        let data = Data(bytes)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HashStackTests-\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        for algorithm in HashAlgorithm.allCases {
            #expect(HashGenerator.hashFile(at: url, with: algorithm) == HashGenerator.hash(data, with: algorithm),
                    "\(algorithm.rawValue) at \(size) bytes")
        }
    }

    @Test("A cancelled file hash stops within one chunk and returns nil")
    func cancelledFileHash() throws {
        let data = Data(repeating: 0xAB, count: 5 * 1024 * 1024)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HashStackTests-\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        for algorithm in HashAlgorithm.allCases {
            var asks = 0
            let digest = HashGenerator.hashFile(at: url, with: algorithm) { asks += 1; return asks > 2 }
            #expect(digest == nil, "\(algorithm.rawValue) returned a digest after cancellation")
            // Asked before each chunk: two read, refused before the third of five.
            #expect(asks == 3, "\(algorithm.rawValue) asked \(asks) times")
        }
        #expect(HashGenerator.hashFile(at: url, with: .sha256, isCancelled: { false })
                == HashGenerator.hash(data, with: .sha256))
    }

    @Test("A missing file returns nil rather than a digest of nothing")
    func missingFile() {
        let url = URL(fileURLWithPath: "/nonexistent/HashStackTests-\(UUID().uuidString)")
        #expect(HashGenerator.hashFile(at: url, with: .sha256) == nil)
    }

    @Test("Digests are lowercase hex of the right length")
    func shape() {
        let lengths: [HashAlgorithm: Int] = [.md5: 32, .sha1: 40, .sha256: 64, .sha512: 128]
        for algorithm in HashAlgorithm.allCases {
            let h = HashGenerator.hash("Stack", with: algorithm)
            #expect(h.count == lengths[algorithm])
            #expect(h.allSatisfy { "0123456789abcdef".contains($0) })
        }
    }
}

struct FileHistoryStoreTests {

    /// One fixed suite per test function, emptied before use. A fresh UUID per
    /// run left a new plist in ~/Library/Preferences every time the tests ran
    /// (removing a domain empties the file but never deletes it); a fixed name
    /// keeps the count bounded at one file per test.
    private func makeDefaults(_ test: String = #function) -> UserDefaults {
        let name = "HashStackTests.\(test.filter { $0.isLetter || $0.isNumber })"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test("Most-recent-first, deduplicated, capped at 10, persisted")
    func history() {
        let defaults = makeDefaults()
        let store = FileHistoryStore(defaults: defaults)
        for i in 0..<12 { store.add(URL(fileURLWithPath: "/tmp/f\(i)")) }
        store.add(URL(fileURLWithPath: "/tmp/f5"))
        #expect(store.paths.count == 10)
        #expect(store.paths.first == "/tmp/f5")
        #expect(store.paths.filter { $0 == "/tmp/f5" }.count == 1)
        #expect(!store.paths.contains("/tmp/f0"))
        #expect(FileHistoryStore(defaults: defaults).paths == store.paths)
        store.clear()
        #expect(FileHistoryStore(defaults: defaults).paths.isEmpty)
    }

    /// Stands in for the sandbox: a bookmark is the path's bytes, and every
    /// call the store makes is recorded.
    private final class FakeBookmarks {
        var started: [String] = []
        var stopped: [String] = []
        var made = 0
        var failMake = false
        /// Bookmarked path → where the file is now.
        var moves: [String: String] = [:]
        var stale: Set<String> = []
        var unresolvable: Set<String> = []

        var bookmarks: FileBookmarks {
            FileBookmarks(
                make: { url in
                    if self.failMake { return nil }
                    self.made += 1
                    return Data(url.path.utf8)
                },
                resolve: { data in
                    let path = String(decoding: data, as: UTF8.self)
                    if self.unresolvable.contains(path) { return nil }
                    return (URL(fileURLWithPath: self.moves[path] ?? path), self.stale.contains(path))
                },
                startAccess: { url in
                    self.started.append(url.path)
                    return true
                },
                stopAccess: { url in self.stopped.append(url.path) })
        }
    }

    @Test("Re-opening a recent file goes through its bookmark and holds access until the next pick")
    func openHoldsAccess() {
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: makeDefaults(), bookmarks: fake.bookmarks)
        store.add(URL(fileURLWithPath: "/tmp/a"))
        store.add(URL(fileURLWithPath: "/tmp/b"))
        #expect(store.entries.allSatisfy { $0.bookmark != nil })

        #expect(store.open("/tmp/a").path == "/tmp/a")
        #expect(fake.started == ["/tmp/a"])
        #expect(fake.stopped.isEmpty)

        _ = store.open("/tmp/b")
        #expect(fake.started == ["/tmp/a", "/tmp/b"])
        #expect(fake.stopped == ["/tmp/a"])

        // The same file again starts before it stops, so access never lapses.
        _ = store.open("/tmp/b")
        #expect(fake.started == ["/tmp/a", "/tmp/b", "/tmp/b"])
        #expect(fake.stopped == ["/tmp/a", "/tmp/b"])

        store.releaseAccess()
        store.releaseAccess()
        #expect(fake.stopped.count == fake.started.count)
    }

    @Test("Bookmarks survive a relaunch; a moved file is followed and its row takes the new path")
    func movedFileFollowed() {
        let defaults = makeDefaults()
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks)
        store.add(URL(fileURLWithPath: "/tmp/old"))
        store.add(URL(fileURLWithPath: "/tmp/new"))
        store.add(URL(fileURLWithPath: "/tmp/other"))

        let relaunched = FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks)
        #expect(relaunched.entries == store.entries)

        // Moved on top of a file that has its own row: one row is left.
        fake.moves["/tmp/old"] = "/tmp/new"
        #expect(relaunched.open("/tmp/old").path == "/tmp/new")
        #expect(relaunched.paths == ["/tmp/other", "/tmp/new"])
        #expect(FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks).paths == ["/tmp/other", "/tmp/new"])
    }

    @Test("A stale bookmark still opens, and the next successful add replaces it")
    func staleBookmark() {
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: makeDefaults(), bookmarks: fake.bookmarks)
        store.add(URL(fileURLWithPath: "/tmp/s"))
        fake.stale.insert("/tmp/s")
        let url = store.open("/tmp/s")
        #expect(url.path == "/tmp/s")
        #expect(fake.started == ["/tmp/s"])
        store.add(url)
        #expect(fake.made == 2)
    }

    @Test("A failed bookmark keeps the one the row already had")
    func failedBookmarkKeepsOld() {
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: makeDefaults(), bookmarks: fake.bookmarks)
        store.add(URL(fileURLWithPath: "/tmp/k"))
        let kept = store.entries[0].bookmark
        fake.failMake = true
        store.add(URL(fileURLWithPath: "/tmp/k"))
        #expect(kept != nil)
        #expect(store.entries[0].bookmark == kept)
        store.add(URL(fileURLWithPath: "/tmp/fresh"))
        #expect(store.entries[0].bookmark == nil)
    }

    @Test("No bookmark, or one that no longer resolves, falls back to the path and starts no access")
    func fallbackToPath() {
        let defaults = makeDefaults()
        defaults.set(["/tmp/legacy"], forKey: "HashStack.fileHistory.v1")
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks)
        #expect(store.paths == ["/tmp/legacy"])
        #expect(store.entries[0].bookmark == nil)
        #expect(store.open("/tmp/legacy").path == "/tmp/legacy")

        store.add(URL(fileURLWithPath: "/tmp/gone"))
        fake.unresolvable.insert("/tmp/gone")
        #expect(store.open("/tmp/gone").path == "/tmp/gone")
        #expect(store.open("/tmp/never-listed").path == "/tmp/never-listed")
        #expect(fake.started.isEmpty)
    }

    @Test("Clear is for good: the paths-only list from the previous build is removed too")
    func clearBeatsLegacy() {
        let defaults = makeDefaults()
        defaults.set(["/tmp/legacy"], forKey: "HashStack.fileHistory.v1")
        let fake = FakeBookmarks()
        let store = FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks)
        #expect(store.paths == ["/tmp/legacy"])
        // Carried over, not rewritten, so a downgrade still finds its own list.
        store.add(URL(fileURLWithPath: "/tmp/new"))
        #expect(defaults.array(forKey: "HashStack.fileHistory.v1") as? [String] == ["/tmp/legacy"])
        store.clear()
        #expect(FileHistoryStore(defaults: defaults, bookmarks: fake.bookmarks).paths.isEmpty)
        // PRIVACY.md says Clear removes the list: no copy of it stays behind.
        #expect(defaults.object(forKey: "HashStack.fileHistory.v1") == nil)
    }

    @Test("A real bookmark follows a renamed file")
    func realBookmarkFollowsRename() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HashStackTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = dir.appendingPathComponent("before.bin")
        let after = dir.appendingPathComponent("after.bin")
        try Data("Stack".utf8).write(to: before)

        // Plain bookmarks: the test process isn't sandboxed.
        let plain = FileBookmarks(
            make: { try? $0.bookmarkData() },
            resolve: { data in
                var isStale = false
                guard let url = try? URL(resolvingBookmarkData: data,
                                         bookmarkDataIsStale: &isStale) else { return nil }
                return (url, isStale)
            },
            startAccess: { _ in false },
            stopAccess: { _ in })
        let store = FileHistoryStore(defaults: makeDefaults(), bookmarks: plain)
        store.add(before)
        try FileManager.default.moveItem(at: before, to: after)

        let opened = store.open(before.path)
        #expect(opened.lastPathComponent == "after.bin")
        #expect(try Data(contentsOf: opened) == Data("Stack".utf8))
        #expect(store.paths.map { ($0 as NSString).lastPathComponent } == ["after.bin"])
    }
}
