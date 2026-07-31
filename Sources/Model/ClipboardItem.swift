import Foundation
import SwiftData

enum ItemKind: String {
    case text
    case image
    case file
}

enum TextSubtype: String {
    case link
    case color
}

private enum TextPreviewClassification {
    case rich(RichTextPreviewKind)
    case code(CodeLanguage)
    case plain
}

private final class TextPreviewClassificationBox: NSObject {
    let value: TextPreviewClassification

    init(_ value: TextPreviewClassification) {
        self.value = value
    }
}

private enum TextPreviewClassificationCache {
    private static let values: NSCache<NSString, TextPreviewClassificationBox> = {
        let cache = NSCache<NSString, TextPreviewClassificationBox>()
        cache.countLimit = 512
        return cache
    }()

    static func resolve(
        text: String,
        contentHash: String,
        subtype: TextSubtype?
    ) -> TextPreviewClassification {
        let key = "\(contentHash)|\(subtype?.rawValue ?? "text")" as NSString
        if let cached = values.object(forKey: key) {
            return cached.value
        }

        let classification: TextPreviewClassification
        if subtype == .color {
            classification = .plain
        } else if let rich = RichTextPreviewKind.detect(text) {
            classification = .rich(rich)
        } else if let language = CodeSnippetDetector.detect(text) {
            classification = .code(language)
        } else {
            classification = .plain
        }

        values.setObject(TextPreviewClassificationBox(classification), forKey: key)
        return classification
    }
}

@Model
final class ClipboardItem {
    #Index<ClipboardItem>([\.contentHash], [\.lastCopiedAt])

    var kind: String
    var textSubtype: String?
    var textContent: String?
    var imagePath: String?
    var fileURLPaths: [String]
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var byteSize: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var firstCopiedAt: Date
    var lastCopiedAt: Date
    var timesCopied: Int
    @Attribute(.unique) var contentHash: String

    init(
        kind: ItemKind,
        textSubtype: TextSubtype? = nil,
        textContent: String? = nil,
        imagePath: String? = nil,
        fileURLPaths: [String] = [],
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        byteSize: Int,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        contentHash: String,
        date: Date = .now
    ) {
        self.kind = kind.rawValue
        self.textSubtype = textSubtype?.rawValue
        self.textContent = textContent
        self.imagePath = imagePath
        self.fileURLPaths = fileURLPaths
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.firstCopiedAt = date
        self.lastCopiedAt = date
        self.timesCopied = 1
        self.contentHash = contentHash
    }
}

extension ClipboardItem {
    var itemKind: ItemKind { ItemKind(rawValue: kind) ?? .text }

    var subtype: TextSubtype? { textSubtype.flatMap(TextSubtype.init(rawValue:)) }

    var richTextPreviewKind: RichTextPreviewKind? {
        guard itemKind == .text,
              let textContent
        else {
            return nil
        }
        guard case .rich(let kind) = TextPreviewClassificationCache.resolve(
            text: textContent,
            contentHash: contentHash,
            subtype: subtype
        ) else {
            return nil
        }
        return kind
    }

    var webURL: URL? {
        guard let richTextPreviewKind else { return nil }
        switch richTextPreviewKind {
        case .youtube(let link):
            return link.originalURL
        case .link(let url):
            return url
        case .markdown:
            return nil
        }
    }

    var codeLanguage: CodeLanguage? {
        switch itemKind {
        case .text:
            guard subtype != .color,
                  let textContent,
                  case .code(let language) = TextPreviewClassificationCache.resolve(
                      text: textContent,
                      contentHash: contentHash,
                      subtype: subtype
                  )
            else {
                return nil
            }
            return language
        case .file:
            guard case .code(let language) = PreviewFileKind.resolve(paths: fileURLPaths) else {
                return nil
            }
            return language
        case .image:
            return nil
        }
    }

    var previewTypeLabel: String {
        if let richTextPreviewKind {
            switch richTextPreviewKind {
            case .markdown:
                return "Markdown"
            case .youtube:
                return "YouTube"
            case .link:
                return "Link"
            }
        }
        if let codeLanguage {
            return codeLanguage.displayName
        }
        if itemKind == .file {
            switch PreviewFileKind.resolve(paths: fileURLPaths) {
            case .image:
                return "Image"
            case .markdown:
                return "Markdown"
            case .code(let language):
                return language.displayName
            case .other:
                switch LocalMediaPreviewKind.resolve(paths: fileURLPaths) {
                case .audio:
                    return "Audio"
                case .pdf:
                    return "PDF"
                case nil:
                    break
                }
            }
        }
        return contentTypeLabel
    }

    var displayTitle: String {
        switch itemKind {
        case .text:
            let firstLine = (textContent ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard let firstLine, !firstLine.isEmpty else { return "Empty text" }

            if case .markdown? = richTextPreviewKind {
                let stripped = firstLine.replacingOccurrences(
                    of: #"^#{1,6}\s+"#,
                    with: "",
                    options: .regularExpression
                )
                return stripped.isEmpty ? firstLine : stripped
            }
            return firstLine
        case .image:
            if let w = pixelWidth, let h = pixelHeight { return "Image (\(w)×\(h))" }
            return "Image"
        case .file:
            let names = fileURLPaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            guard let first = names.first else { return "File" }
            return names.count > 1 ? "\(first) +\(names.count - 1)" : first
        }
    }

    /// Shared search predicate for the panel UI and the Local MCP surface,
    /// so both filter history identically.
    func matches(searchQuery query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if let text = textContent, text.localizedCaseInsensitiveContains(query) { return true }
        if fileURLPaths.contains(where: {
            URL(fileURLWithPath: $0).lastPathComponent.localizedCaseInsensitiveContains(query)
        }) { return true }
        if let appName = sourceAppName, appName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    var contentTypeLabel: String {
        switch itemKind {
        case .image: return "Image"
        case .file: return fileURLPaths.count > 1 ? "Files" : "File"
        case .text:
            switch subtype {
            case .link: return "Link"
            case .color: return "Color"
            case nil: return "Text"
            }
        }
    }
}
