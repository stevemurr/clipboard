import Foundation
import UniformTypeIdentifiers

/// Preview kinds that are backed by a single local media file.
///
/// This intentionally returns `nil` for a multi-file clipboard item so callers
/// can keep using the compact, generic file summary for those selections.
enum LocalMediaPreviewKind: Equatable {
    case audio
    case pdf

    static func resolve(paths: [String]) -> LocalMediaPreviewKind? {
        guard paths.count == 1, let path = paths.first else { return nil }
        return resolve(url: URL(fileURLWithPath: path))
    }

    static func resolve(url: URL) -> LocalMediaPreviewKind? {
        guard url.isFileURL else { return nil }

        let fileExtension = url.pathExtension.lowercased()
        guard !fileExtension.isEmpty,
              let contentType = UTType(filenameExtension: fileExtension)
        else {
            return nil
        }

        if contentType.conforms(to: .pdf) {
            return .pdf
        }
        if contentType.conforms(to: .audio) {
            return .audio
        }
        return nil
    }
}
