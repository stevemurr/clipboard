import SwiftUI

struct HistoryRowView: View {
    @Environment(HistoryStore.self) private var store
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 22, height: 22)
            Text(item.displayTitle)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("history-row-title")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.itemKind {
        case .image:
            if let filename = item.imagePath, let image = store.imageStore.image(forFilename: filename) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        case .file:
            if let path = item.fileURLPaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
            }
        case .text:
            switch item.subtype {
            case .link:
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
            case .color:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: ColorParser.color(from: item.textContent ?? "") ?? .gray))
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
            case nil:
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
