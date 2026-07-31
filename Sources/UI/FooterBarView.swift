import SwiftUI

struct FooterBarView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.74))
                .frame(width: 26, height: 26)
                .accessibilityLabel("Clipboard History")
                .accessibilityIdentifier("footer-title")

            Spacer()

            Button {
                viewModel.requestAction(.copy)
            } label: {
                shortcutHint("Copy to Clipboard", keys: ["↩"], isPrimary: true)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedItem == nil)
            .accessibilityIdentifier("footer-copy")

            separator

            Button {
                viewModel.requestAction(.quickLook)
            } label: {
                shortcutHint("Quick Look", keys: ["⌘", "Y"])
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedItem == nil)
            .accessibilityIdentifier("footer-quick-look")

            separator

            Button {
                viewModel.togglePreview()
            } label: {
                shortcutHint(
                    "Preview",
                    keys: ["⌘", "P"],
                    isSelected: viewModel.isPreviewPresented
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !viewModel.isPreviewPresented
                    && viewModel.selectedItem == nil
            )
            .accessibilityIdentifier("footer-preview")

            separator

            Button {
                viewModel.toggleActions()
            } label: {
                shortcutHint("Actions", keys: ["⌘", "K"])
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedItem == nil)
            .accessibilityIdentifier("footer-actions")
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clipboardControlSurface.opacity(0.20))
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.clipboardSeparator)
            .frame(width: 1, height: 14)
    }

    private func shortcutHint(
        _ label: String,
        keys: [String],
        isPrimary: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(shortcutLabelColor(
                    isPrimary: isPrimary,
                    isSelected: isSelected
                ))

            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    ClipboardKeyCap(key)
                }
            }
        }
    }

    private func shortcutLabelColor(
        isPrimary: Bool,
        isSelected: Bool
    ) -> Color {
        if isSelected {
            return .accentColor
        }
        return isPrimary ? Color.primary.opacity(0.92) : Color.secondary
    }
}
