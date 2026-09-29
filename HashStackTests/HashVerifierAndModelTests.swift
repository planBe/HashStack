import Foundation
import Testing

struct HashVerifierTests {
    private let sha = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    @Test("An uppercase or space-padded expected hash still matches")
    func tolerantMatch() {
        #expect(HashVerifier.state(expected: sha.uppercased(), computed: sha) == .match)
        #expect(HashVerifier.state(expected: "  \(sha)\n", computed: sha) == .match)
    }

    @Test("Hashes pasted in groups or with an algorithm prefix still match")
    func groupedAndPrefixed() {
        let grouped = stride(from: 0, to: sha.count, by: 8).map { i -> String in
            let start = sha.index(sha.startIndex, offsetBy: i)
            return String(sha[start..<sha.index(start, offsetBy: 8)])
        }.joined(separator: " ")
        #expect(HashVerifier.state(expected: grouped, computed: sha) == .match)
        #expect(HashVerifier.state(expected: "SHA256: \(sha)", computed: sha) == .match)
        #expect(HashVerifier.state(expected: "sha-256:\(sha)", computed: sha) == .match)
    }

    @Test("A one-character difference is DIFFER")
    func oneCharDiffers() {
        var wrong = sha
        wrong.removeLast()
        wrong.append("e")
        #expect(HashVerifier.state(expected: wrong, computed: sha) == .differ)
        #expect(HashVerifier.state(expected: String(sha.dropLast()), computed: sha) == .differ)
    }

    @Test("Empty on either side is idle, not DIFFER")
    func emptyIsIdle() {
        #expect(HashVerifier.state(expected: "", computed: sha) == .idle)
        #expect(HashVerifier.state(expected: "   \n", computed: sha) == .idle)
        #expect(HashVerifier.state(expected: sha, computed: "") == .idle)
    }
}

/// Counts calls to the injected hash function. Locked because the model runs
/// it off the main thread.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(URL, HashAlgorithm)] = []
    func record(_ url: URL, _ algorithm: HashAlgorithm) { lock.lock(); calls.append((url, algorithm)); lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls.count }
    var sawMainThread = false
}

@MainActor
struct FileHashModelTests {
    private let fileA = URL(fileURLWithPath: "/tmp/a.bin")
    private let fileB = URL(fileURLWithPath: "/tmp/b.bin")

    @Test("A file is hashed once per (file, algorithm), however often the view asks")
    func hashesOncePerKey() async {
        let counter = CallCounter()
        let model = FileHashModel { url, algo in
            counter.record(url, algo)
            if Thread.isMainThread { counter.sawMainThread = true }
            return "\(url.lastPathComponent)-\(algo.rawValue)"
        }
        for _ in 0..<5 { model.request(url: fileA, algorithm: .sha256) }
        await model.waitUntilIdle()
        #expect(model.result == "a.bin-SHA-256")
        #expect(counter.count == 1)
        #expect(!counter.sawMainThread, "file hashing ran on the main thread")

        // Same key again (e.g. a keystroke in the Verify field): no new work.
        model.request(url: fileA, algorithm: .sha256)
        await model.waitUntilIdle()
        #expect(counter.count == 1)

        // A new algorithm is new work.
        model.request(url: fileA, algorithm: .md5)
        await model.waitUntilIdle()
        #expect(model.result == "a.bin-MD5")
        #expect(counter.count == 2)
    }

    @Test("A slow stale result never overwrites the newer file's hash")
    func staleResultIgnored() async {
        let model = FileHashModel { url, algo in
            if url.lastPathComponent == "a.bin" { Thread.sleep(forTimeInterval: 0.3) }
            return url.lastPathComponent
        }
        model.request(url: fileA, algorithm: .sha256)
        model.request(url: fileB, algorithm: .sha256)
        await model.waitUntilIdle()
        try? await Task.sleep(nanoseconds: 400_000_000)
        #expect(model.result == "b.bin")
        #expect(!model.isHashing)
    }

    @Test("An unreadable file reports failure instead of a hash")
    func unreadable() async {
        let model = FileHashModel { _, _ in nil }
        model.request(url: fileA, algorithm: .sha256)
        await model.waitUntilIdle()
        #expect(model.result == nil)
        #expect(model.failedURL == fileA)
    }

    @Test("Clearing the file clears the result")
    func clearing() async {
        let model = FileHashModel { url, _ in url.lastPathComponent }
        model.request(url: fileA, algorithm: .sha256)
        await model.waitUntilIdle()
        model.request(url: nil, algorithm: .sha256)
        #expect(model.result == nil)
        #expect(!model.isHashing)
    }
}
