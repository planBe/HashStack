import CryptoKit
import Foundation

nonisolated enum HashAlgorithm: String, CaseIterable, Identifiable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    var id: String { rawValue }
}

/// `nonisolated`: pure functions, and file hashing runs off the main thread
/// (see FileHashModel). The app target defaults to MainActor isolation.
nonisolated enum HashGenerator {
    static func hash(_ data: Data, with algorithm: HashAlgorithm) -> String {
        switch algorithm {
        case .md5: return Insecure.MD5.hash(data: data).hexString
        case .sha1: return Insecure.SHA1.hash(data: data).hexString
        case .sha256: return SHA256.hash(data: data).hexString
        case .sha512: return SHA512.hash(data: data).hexString
        }
    }

    static func hash(_ text: String, with algorithm: HashAlgorithm) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        return hash(data, with: algorithm)
    }

    /// Streams the file in 1 MB chunks so large files don't get loaded into
    /// memory all at once. Returns nil if the file can't be opened, or if
    /// `isCancelled` turns true — it is asked before every chunk, so a
    /// superseded hash stops within one chunk instead of reading to the end.
    /// The default reads the calling task's cancellation (FileHashModel).
    static func hashFile(at url: URL, with algorithm: HashAlgorithm,
                         isCancelled: () -> Bool = { Task.isCancelled }) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        switch algorithm {
        case .md5: return stream(Insecure.MD5(), from: handle, isCancelled: isCancelled)
        case .sha1: return stream(Insecure.SHA1(), from: handle, isCancelled: isCancelled)
        case .sha256: return stream(SHA256(), from: handle, isCancelled: isCancelled)
        case .sha512: return stream(SHA512(), from: handle, isCancelled: isCancelled)
        }
    }

    private static func stream<H: CryptoKit.HashFunction>(_ hasher: H, from handle: FileHandle,
                                                          isCancelled: () -> Bool) -> String? {
        let chunkSize = 1024 * 1024  // 1 MB
        var hasher = hasher
        while true {
            if isCancelled() { return nil }
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().hexString
    }
}

private extension Sequence where Element == UInt8 {
    nonisolated var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
