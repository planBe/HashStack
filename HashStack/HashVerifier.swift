import Foundation

/// Verification outcome — drives the ✓ MATCH / ✗ DIFFER indicator next to the
/// expected-hash field. `.idle` means there is nothing to compare yet.
nonisolated enum VerifyState: Equatable {
    case idle
    case match
    case differ
}

/// The ✓ MATCH / ✗ DIFFER decision, kept out of the view so it can be pinned
/// by tests.
///
/// Publishers print checksums in many shapes: uppercase, wrapped in spaces,
/// split into groups ("ba7816bf 8f01cfea …"), or labelled ("SHA256: …").
/// Checksum files add the file name ("<digest>  name.iso"). None of those
/// change the digest, so none of them may produce ✗ DIFFER —
/// a false DIFFER is the one thing a hash tool must never show.
nonisolated enum HashVerifier {
    static func state(expected: String, computed: String) -> VerifyState {
        let have = normalized(computed)
        guard !have.isEmpty else { return .idle }
        // A pasted line from a checksum file ("<digest>  name.iso", or BSD
        // "SHA256 (name) = <digest>") carries a file name that must not be
        // glued onto the digest. When the paste contains whole digest-length
        // hex words, compare those; several (a whole SHA256SUMS file) match if
        // any one is this file's digest.
        let want = normalized(expected)
        guard !want.isEmpty else { return .idle }
        if want == have { return .match }   // plain, grouped or wrapped digest
        let digests = digestWords(in: expected)
        return digests.contains(have) ? .match : .differ
    }

    /// Whitespace-separated words that are exactly an MD5, SHA-1, SHA-256 or
    /// SHA-512 digest in hex (after dropping a "label:" prefix), lowercased.
    static func digestWords(in raw: String) -> [String] {
        raw.split(whereSeparator: \.isWhitespace).compactMap { word in
            let w = normalized(String(word))
            guard [32, 40, 64, 128].contains(w.count),
                  w.unicodeScalars.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) else { return nil }
            return w
        }
    }

    /// Lowercased, all whitespace removed, and a leading "label:" dropped
    /// (e.g. "SHA256:", "sha-256:", "md5:").
    static func normalized(_ raw: String) -> String {
        var s = raw.lowercased().filter { !$0.isWhitespace }
        if let colon = s.lastIndex(of: ":") {
            s = String(s[s.index(after: colon)...])
        }
        return s
    }
}
