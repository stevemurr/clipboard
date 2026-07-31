import Foundation

enum ClipboardAction: String, Identifiable, CaseIterable {
    case copy
    case open
    case quickLook
    case delete

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .open: return "arrow.up.forward.app"
        case .quickLook: return "eye"
        case .delete: return "trash"
        }
    }

    var shortcutKeys: [String] {
        switch self {
        case .copy: return ["↩"]
        case .open: return ["⌘", "↩"]
        case .quickLook: return ["⌘", "Y"]
        case .delete: return ["⌘", "⌫"]
        }
    }

    var isDestructive: Bool {
        self == .delete
    }

    func title(for item: ClipboardItem?) -> String {
        switch self {
        case .copy:
            return "Copy to Clipboard"
        case .open:
            guard let item else { return "Open" }
            if item.subtype == .link { return "Open Link" }
            return item.fileURLPaths.count > 1 ? "Open Files" : "Open File"
        case .quickLook:
            return "Quick Look"
        case .delete:
            return "Delete from History"
        }
    }
}
