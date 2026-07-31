import SwiftUI

struct HistoryPanelView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
            Color.clipboardSurface.opacity(0.84)

            VStack(spacing: 0) {
                SearchBarView(viewModel: viewModel, focus: $searchFocused)
                    .frame(height: ClipboardStyle.headerHeight)

                Divider().opacity(0.65)

                HStack(spacing: 0) {
                    HistoryListView(viewModel: viewModel)
                        .frame(width: historyRegionWidth)

                    if viewModel.isPreviewPresented {
                        DetailPaneView(item: viewModel.selectedItem)
                            .frame(width: ClipboardStyle.previewDrawerWidth)
                            .frame(maxHeight: .infinity)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.clipboardSeparator.opacity(0.65))
                                    .frame(width: 1)
                            }
                            .transition(previewTransition)
                    }
                }

                Divider().opacity(0.65)

                FooterBarView(viewModel: viewModel)
                    .frame(height: ClipboardStyle.footerHeight)
            }

            if viewModel.isActionsPresented {
                ClipboardActionsPalette(viewModel: viewModel)
                    .padding(.trailing, 8)
                    .padding(.bottom, 45)
                    .transition(.opacity.combined(
                        with: .scale(scale: 0.98, anchor: .bottomTrailing)
                    ))
            }
        }
        .frame(width: panelWidth, height: ClipboardStyle.panelHeight)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ClipboardStyle.panelCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: ClipboardStyle.panelCornerRadius,
                style: .continuous
            )
            .stroke(Color.clipboardSeparator.opacity(0.82), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.isActionsPresented)
        .animation(drawerAnimation, value: viewModel.isPreviewPresented)
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.isActionsPresented) {
            if viewModel.isActionsPresented {
                // Footer clicks must not pull typing away from search.
                DispatchQueue.main.async { searchFocused = true }
            }
        }
        .onChange(of: viewModel.presentationToken) {
            // Focus can only land after the window becomes key.
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: viewModel.isPreviewPresented) {
            // Toolbar clicks must not pull typing away from search.
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    private var panelWidth: CGFloat {
        viewModel.isPreviewPresented
            ? ClipboardStyle.expandedPanelWidth
            : ClipboardStyle.panelWidth
    }

    private var historyRegionWidth: CGFloat {
        viewModel.isPreviewPresented
            ? ClipboardStyle.drawerHistoryWidth
            : ClipboardStyle.panelWidth
    }

    private var drawerAnimation: Animation? {
        reduceMotion
            ? nil
            : .easeInOut(duration: ClipboardStyle.drawerAnimationDuration)
    }

    private var previewTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .move(edge: .trailing).combined(with: .opacity)
    }
}
