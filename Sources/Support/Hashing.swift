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
        let paths = urls.map(\.path).sorted()
        var framed = Data()

        func append(_ value: UInt64) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { framed.append(contentsOf: $0) }
        }

        append(UInt64(paths.count))
        for path in paths {
            let bytes = Data(path.utf8)
            append(UInt64(bytes.count))
            framed.append(bytes)
        }
        return sha256(framed)
    }
}
