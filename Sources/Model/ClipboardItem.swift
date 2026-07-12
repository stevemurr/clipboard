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

    var displayTitle: String {
        switch itemKind {
        case .text:
            let firstLine = (textContent ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return firstLine?.isEmpty == false ? firstLine! : "Empty text"
        case .image:
            if let w = pixelWidth, let h = pixelHeight { return "Image (\(w)×\(h))" }
            return "Image"
        case .file:
            let names = fileURLPaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            guard let first = names.first else { return "File" }
            return names.count > 1 ? "\(first) +\(names.count - 1)" : first
        }
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
