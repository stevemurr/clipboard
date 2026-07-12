import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $viewModel.selectedItemID) {
                ForEach(viewModel.sections) { group in
                    Section {
                        ForEach(group.items) { item in
                            HistoryRowView(
                                item: item,
                                isSelected: item.persistentModelID == viewModel.selectedItemID
                            )
                            .tag(item.persistentModelID)
                            .id(item.persistentModelID)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                        }
                    } header: {
                        Text(group.section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.visibleItems.isEmpty {
                    emptyState
                }
            }
            .onChange(of: viewModel.selectedItemID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(viewModel.searchText.isEmpty ? "No clipboard history yet" : "No matches")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
