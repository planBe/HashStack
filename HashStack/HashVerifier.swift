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
/// None of those change the digest, so none of them may produce ✗ DIFFER —
/// a false DIFFER is the one thing a hash tool must never show.
nonisolated enum HashVerifier {
    static func state(expected: String, computed: String) -> VerifyState {
        let want = normalized(expected)
        let have = normalized(computed)
        guard !want.isEmpty, !have.isEmpty else { return .idle }
        return want == have ? .match : .differ
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
