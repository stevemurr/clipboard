import CryptoKit
import Foundation

/// Content hashes must be stable across launches (dedup keys are persisted),
/// so these use SHA256 rather than the per-process-seeded `Swift.Hasher`.
enum Hashing {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }

    static func sha256(fileURLs urls: [URL]) -> String {
        sha256(urls.map(\.path).sorted().joined(separator: "\n"))
    }
}
