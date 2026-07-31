import SwiftUI

struct ClipboardActionsPalette: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.selectedItem?.displayTitle ?? "Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)

            ForEach(Array(viewModel.availableActions.enumerated()), id: \.element.id) { index, action in
                Button {
                    viewModel.selectAction(index: index)
                    viewModel.requestAction(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 20)

                        Text(action.title(for: viewModel.selectedItem))
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        HStack(spacing: 3) {
                            ForEach(action.shortcutKeys, id: \.self) {
                                ClipboardKeyCap($0)
                            }
                        }
                    }
                    .foregroundStyle(action.isDestructive ? Color.red : Color.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(index == viewModel.actionsSelectionIndex
                                ? Color.primary.opacity(0.085)
                                : Color.clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 7)
                .accessibilityAddTraits(
                    index == viewModel.actionsSelectionIndex ? .isSelected : []
                )
                .onHover { hovering in
                    if hovering {
                        viewModel.selectAction(index: index)
                    }
                }
                .accessibilityIdentifier("clipboard-action-\(action.rawValue)")
            }

            Spacer(minLength: 6)
        }
        .frame(
            width: 350,
            height: CGFloat(52 + viewModel.availableActions.count * 40)
        )
        .background {
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
                .overlay(Color.clipboardSurface.opacity(0.56))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
    }
}
