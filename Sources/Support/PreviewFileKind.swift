import Foundation
import UniformTypeIdentifiers

enum PreviewFileKind: Equatable {
    case image
    case code(CodeLanguage)
    case markdown
    case other

    static func resolve(paths: [String]) -> PreviewFileKind {
        guard paths.count == 1, let path = paths.first else { return .other }
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()

        if let type = UTType(filenameExtension: fileExtension), type.conforms(to: .image) {
            return .image
        }
        if MarkdownDetector.isMarkdownFileExtension(fileExtension) {
            return .markdown
        }
        if let language = CodeLanguage.from(fileExtension: fileExtension) {
            return .code(language)
        }
        return .other
    }
}
