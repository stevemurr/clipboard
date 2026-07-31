import KeyboardShortcuts
import SwiftUI

struct SearchBarView: View {
    @Bindable var viewModel: AppViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
            TextField("Search clipboard history", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .focused(focus)
                .accessibilityIdentifier("search-field")

            Picker("", selection: $viewModel.typeFilter) {
                ForEach(TypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .accessibilityLabel("Content type filter")
            .accessibilityIdentifier("type-filter")

            HStack(spacing: 5) {
                Text("Hotkey")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.72))
                ClipboardKeyCap(hotKeyDescription)
            }

            Button {
                viewModel.togglePreview()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        viewModel.isPreviewPresented
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        previewToggleBackground,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .overlay {
                        if viewModel.isPreviewPresented {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.28), lineWidth: 0.5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(
                !viewModel.isPreviewPresented
                    && viewModel.selectedItem == nil
            )
            .help("\(viewModel.isPreviewPresented ? "Hide" : "Show") Preview (⌘P)")
            .accessibilityLabel(
                viewModel.isPreviewPresented ? "Hide Preview" : "Show Preview"
            )
            .accessibilityIdentifier("header-preview-toggle")

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .help("Clipboard Settings (⌘,)")
            .accessibilityIdentifier("header-settings")
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
    }

    private var hotKeyDescription: String {
        KeyboardShortcuts.Shortcut(name: .togglePanel)?.description ?? "⇧⌘V"
    }

    private var previewToggleBackground: Color {
        viewModel.isPreviewPresented
            ? Color.accentColor.opacity(0.12)
            : Color.primary.opacity(0.07)
    }
}
