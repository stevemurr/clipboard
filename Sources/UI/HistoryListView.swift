import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        ScrollViewReader { proxy in
            // Deliberately not a List: its NSTableView backing paints an
            // opaque background over the panel material.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(viewModel.sections) { group in
                        Text(group.section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                        ForEach(group.items) { item in
                            HistoryRowView(
                                item: item,
                                isSelected: item.persistentModelID == viewModel.selectedItemID
                            )
                            .id(item.persistentModelID)
                            .onTapGesture {
                                viewModel.selectedItemID = item.persistentModelID
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
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
