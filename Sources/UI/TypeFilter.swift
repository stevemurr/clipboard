import Foundation

enum TypeFilter: String, CaseIterable, Identifiable {
    case all = "All Types"
    case text = "Text"
    case images = "Images"
    case files = "Files"
    case links = "Links"

    var id: String { rawValue }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.itemKind == .text
        case .images: return item.itemKind == .image
        case .files: return item.itemKind == .file
        case .links: return item.itemKind == .text && item.subtype == .link
        }
    }
}
