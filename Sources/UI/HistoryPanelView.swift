import SwiftUI

struct HistoryPanelView: View {
    @Bindable var viewModel: AppViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(viewModel: viewModel, focus: $searchFocused)
            Divider()
            HStack(spacing: 0) {
                HistoryListView(viewModel: viewModel)
                    .frame(width: 330)
                Divider()
                DetailPaneView(item: viewModel.selectedItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            FooterBarView()
        }
        .frame(width: 750, height: 470)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.presentationToken) {
            // Focus can only land after the window becomes key.
            DispatchQueue.main.async { searchFocused = true }
        }
    }
}
