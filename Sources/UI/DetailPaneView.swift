import SwiftUI

struct DetailPaneView: View {
    @Environment(HistoryStore.self) private var store
    let item: ClipboardItem?

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                preview(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                InformationTableView(item: item)
            }
        } else {
            Text("No Selection")
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func preview(for item: ClipboardItem) -> some View {
        switch item.itemKind {
        case .text:
            if item.subtype == .color, let color = ColorParser.color(from: item.textContent ?? "") {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: color))
                        .frame(width: 140, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.separator, lineWidth: 1)
                        )
                    Text(item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    Text(item.textContent ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(14)
                }
            }
        case .image:
            if let filename = item.imagePath, let image = store.imageStore.image(forFilename: filename) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(radius: 8)
                    .padding(20)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
            }
        case .file:
            VStack(spacing: 10) {
                if let path = item.fileURLPaths.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                }
                ForEach(item.fileURLPaths.prefix(4), id: \.self) { path in
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if item.fileURLPaths.count > 4 {
                    Text("+\(item.fileURLPaths.count - 4) more")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
    }
}
