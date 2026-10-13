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

    /// Second pass, 2026-09-29. The commonest thing to paste is a line from a
    /// SHA256SUMS file, which carries the file name. Removing whitespace glued
    /// the name onto the digest, so a correct download showed DIFFER.
    @Test("A checksum-file line (GNU or BSD format) matches on its digest")
    func checksumFileLines() {
        #expect(HashVerifier.state(expected: "\(sha)  ubuntu-24.04-desktop-amd64.iso", computed: sha) == .match)
        #expect(HashVerifier.state(expected: "\(sha) *setup.exe\n", computed: sha) == .match)
        #expect(HashVerifier.state(expected: "SHA256 (Xcode 26.xip) = \(sha)", computed: sha) == .match)
        // The file name must not rescue a wrong digest.
        var wrong = sha
        wrong.removeLast()
        wrong.append("e")
        #expect(HashVerifier.state(expected: "\(wrong)  ubuntu.iso", computed: sha) == .differ)
        // A SHA-256 wrapped as two 32-character halves looks like two MD5
        // words; it must still match as one digest.
        let half = sha.index(sha.startIndex, offsetBy: 32)
        #expect(HashVerifier.state(expected: "\(sha[..<half])\n\(sha[half...])", computed: sha) == .match)
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

/// Records how far a fake hash got and whether it saw its cancellation.
private final class ChunkProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var read = 0
    private var cancelled = false
    func chunk() { lock.lock(); read += 1; lock.unlock() }
    func sawCancel() { lock.lock(); cancelled = true; lock.unlock() }
    var chunks: Int { lock.lock(); defer { lock.unlock() }; return read }
    var wasCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
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

    /// Found by the 2026-09-29 second pass: the stale result was discarded, but the
    /// detached hash of the old file kept reading to the end — a multi-GB
    /// file picked by mistake held a core and the disk for seconds.
    @Test("A superseded file stops being read within a chunk")
    func supersededHashStops() async throws {
        let probe = ChunkProbe()
        let model = FileHashModel { url, _ in
            guard url.lastPathComponent == "a.bin" else { return url.lastPathComponent }
            for _ in 0..<200 {  // 200 × 10 ms chunks: a 2 s file
                if Task.isCancelled { probe.sawCancel(); return nil }
                Thread.sleep(forTimeInterval: 0.01)
                probe.chunk()
            }
            return "a.bin"
        }
        model.request(url: fileA, algorithm: .sha256)
        try await Task.sleep(nanoseconds: 100_000_000)
        let before = probe.chunks
        model.request(url: fileB, algorithm: .sha256)
        await model.waitUntilIdle()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(before > 0, "the old file was not mid-read, so this proves nothing")
        #expect(probe.wasCancelled, "the old file's hash was never told it was superseded")
        #expect(probe.chunks <= before + 2, "read \(probe.chunks - before) chunks after being superseded")
        #expect(model.result == "b.bin")
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
