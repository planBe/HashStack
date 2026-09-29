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
}
