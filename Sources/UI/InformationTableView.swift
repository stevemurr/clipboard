import SwiftUI

struct InformationTableView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Information")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if item.sourceAppName != nil || item.sourceAppBundleID != nil {
                row("Source") {
                    HStack(spacing: 5) {
                        if let icon = AppIconProvider.icon(forBundleID: item.sourceAppBundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        Text(item.sourceAppName ?? item.sourceAppBundleID ?? "")
                    }
                }
            }

            row("Content type") { Text(item.contentTypeLabel) }

            switch item.itemKind {
            case .image:
                if let w = item.pixelWidth, let h = item.pixelHeight {
                    row("Dimensions") { Text("\(w)×\(h)") }
                }
                row("Image size") { Text(byteString(item.byteSize)) }
            case .text:
                let text = item.textContent ?? ""
                row("Characters") { Text("\(text.count)") }
                row("Words") { Text("\(wordCount(text))") }
            case .file:
                if item.fileURLPaths.count > 1 {
                    row("Files") { Text("\(item.fileURLPaths.count)") }
                } else if let path = item.fileURLPaths.first {
                    row("Path") {
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if item.byteSize > 0 {
                    row("Size") { Text(byteString(item.byteSize)) }
                }
            }

            if item.timesCopied > 1 {
                row("Times copied") { Text("\(item.timesCopied)") }
            }
            row("Last copied") { Text(item.lastCopiedAt, format: .relative(presentation: .named)) }
            row("First copied") { Text(item.firstCopiedAt, format: .dateTime.day().month().year().hour().minute()) }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func row(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            value()
        }
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
