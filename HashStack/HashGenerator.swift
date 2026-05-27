import CryptoKit
import Foundation

enum HashAlgorithm: String, CaseIterable, Identifiable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    var id: String { rawValue }
}

enum HashGenerator {
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
    /// memory all at once. Returns nil if the file can't be opened.
    static func hashFile(at url: URL, with algorithm: HashAlgorithm) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 1024 * 1024  // 1 MB

        switch algorithm {
        case .md5:
            var hasher = Insecure.MD5()
            while case let chunk = handle.readData(ofLength: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().hexString
        case .sha1:
            var hasher = Insecure.SHA1()
            while case let chunk = handle.readData(ofLength: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().hexString
        case .sha256:
            var hasher = SHA256()
            while case let chunk = handle.readData(ofLength: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().hexString
        case .sha512:
            var hasher = SHA512()
            while case let chunk = handle.readData(ofLength: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().hexString
        }
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
