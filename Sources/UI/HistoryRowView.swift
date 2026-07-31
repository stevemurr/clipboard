import SwiftUI

struct HistoryRowView: View {
    @Environment(HistoryStore.self) private var store
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 20, height: 20)

            Text(item.displayTitle)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: ClipboardStyle.historyRowHeight)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.displayTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("history-row")
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.itemKind {
        case .image:
            if let filename = item.imagePath, let image = store.imageStore.image(forFilename: filename) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        case .file:
            switch PreviewFileKind.resolve(paths: item.fileURLPaths) {
            case .code:
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            case .markdown:
                Image(systemName: "doc.richtext")
                    .foregroundStyle(.secondary)
            case .image:
                workspaceFileIcon
            case .other:
                switch LocalMediaPreviewKind.resolve(paths: item.fileURLPaths) {
                case .audio:
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                case .pdf:
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                case nil:
                    workspaceFileIcon
                }
            }
        case .text:
            if let richPreview = item.richTextPreviewKind {
                switch richPreview {
                case .markdown:
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                case .youtube:
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(.secondary)
                case .link:
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                }
            } else if item.subtype == .color {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: ColorParser.color(from: item.textContent ?? "") ?? .gray))
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
            } else if item.codeLanguage != nil {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var workspaceFileIcon: some View {
        if let path = item.fileURLPaths.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }
}
