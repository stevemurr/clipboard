import AppKit
import SwiftUI

enum ClipboardStyle {
    static let panelWidth: CGFloat = 824
    static let expandedPanelWidth: CGFloat = 1040
    static let panelHeight: CGFloat = 512
    static let drawerHistoryWidth: CGFloat = 576
    static let previewDrawerWidth: CGFloat = 464
    static let drawerAnimationDuration: TimeInterval = 0.18
    static let headerHeight: CGFloat = 59
    static let footerHeight: CGFloat = 39
    static let sectionHeaderHeight: CGFloat = 32
    static let historyRowHeight: CGFloat = 42
    static let panelCornerRadius: CGFloat = 16
}

struct ClipboardKeyCap: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 6)
            .frame(minWidth: 23, minHeight: 22)
            .background(
                Color.primary.opacity(0.075),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.clipboardSeparator.opacity(0.72), lineWidth: 0.5)
            }
    }
}

extension Color {
    static let clipboardSurface = Color(nsColor: NSColor(name: "ClipboardSurface") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 0.105, green: 0.105, blue: 0.115, alpha: 1)
        }
        return NSColor(srgbRed: 0.94, green: 0.94, blue: 0.95, alpha: 1)
    })

    static let clipboardControlSurface = Color(nsColor: .controlBackgroundColor)
    static let clipboardSeparator = Color(nsColor: .separatorColor)
}
