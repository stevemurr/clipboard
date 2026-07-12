import SwiftUI

struct FooterBarView: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 11))
                Text("Clipboard History")
                    .accessibilityIdentifier("footer-title")
            }
            .foregroundStyle(.secondary)

            Spacer()

            shortcutHint("Copy to Clipboard", keys: ["↵"])
            Divider().frame(height: 14)
            shortcutHint("Quick Look", keys: ["⌘", "K"])
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func shortcutHint(_ label: String, keys: [String]) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 18)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.08))
                        )
                }
            }
        }
    }
}
