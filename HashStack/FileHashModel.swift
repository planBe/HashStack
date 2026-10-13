import Combine
import Foundation

/// Hashes the picked file once per (file, algorithm), off the main thread.
///
/// Before this existed the view computed the file hash inside `body` — three
/// times per render (hash output, verify badge, verify border) plus once more
/// when the file was adopted — synchronously on the main thread. At ~0.6 s per
/// GiB for SHA-256 that froze the popover for seconds on every keystroke in
/// the Verify field. Now the view only ever reads `result`.
@MainActor
final class FileHashModel: ObservableObject {
    /// Runs inside a detached task that is cancelled when the request is
    /// superseded, so it can poll `Task.isCancelled` and give up early.
    typealias HashFunction = @Sendable (URL, HashAlgorithm) -> String?

    /// The digest for the current request, or nil while hashing / on failure.
    @Published private(set) var result: String?
    @Published private(set) var isHashing = false
    /// Set when the requested file couldn't be read (moved, deleted, or — in
    /// the sandbox — no longer accessible).
    @Published private(set) var failedURL: URL?

    private let hashFunction: HashFunction
    private var currentKey: Key?
    private var task: Task<Void, Never>?

    private struct Key: Equatable {
        let url: URL
        let algorithm: HashAlgorithm
    }

    /// `hashFunction` is injectable so tests can count calls and control timing.
    init(hashFunction: @escaping HashFunction = { HashGenerator.hashFile(at: $0, with: $1) }) {
        self.hashFunction = hashFunction
    }

    /// Asks for the hash of `url` with `algorithm`. Repeating the current
    /// request is free; a new one supersedes (and discards) any in flight.
    func request(url: URL?, algorithm: HashAlgorithm) {
        guard let url else {
            task?.cancel()
            task = nil
            currentKey = nil
            result = nil
            failedURL = nil
            isHashing = false
            return
        }
        let key = Key(url: url, algorithm: algorithm)
        guard key != currentKey else { return }

        task?.cancel()
        currentKey = key
        result = nil
        failedURL = nil
        isHashing = true

        let hashFunction = self.hashFunction
        task = Task { [weak self] in
            // A detached task does not inherit cancellation, so pass it on;
            // otherwise a superseded multi-GB file keeps being read to the end.
            let work = Task.detached(priority: .userInitiated) {
                hashFunction(url, algorithm)
            }
            let digest = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
            guard let self, !Task.isCancelled, self.currentKey == key else { return }
            self.result = digest
            self.failedURL = digest == nil ? url : nil
            self.isHashing = false
        }
    }

    /// Waits for the in-flight request, if any. Used by tests.
    func waitUntilIdle() async {
        await task?.value
    }
}
