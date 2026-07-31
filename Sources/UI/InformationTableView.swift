import SwiftUI

struct InformationTableView: View {
    let item: ClipboardItem
    var detailText: String?

    var body: some View {
        HStack(spacing: 12) {
            if let detailText {
                Text(detailText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(byteString(item.byteSize))
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.secondary)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("preview-metadata")
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
