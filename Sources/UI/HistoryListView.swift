import SwiftUI

struct HistoryListView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        ScrollViewReader { proxy in
            // Deliberately not a List: its NSTableView backing paints an
            // opaque background over the panel material.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sections) { group in
                        sectionHeader(group.section.title)

                        ForEach(group.items) { item in
                            HistoryRowView(
                                item: item,
                                isSelected: item.persistentModelID == viewModel.selectedItemID
                            )
                            .id(item.persistentModelID)
                            .onTapGesture {
                                viewModel.selectedItemID = item.persistentModelID
                            }
                            .onHover { hovering in
                                if hovering, !viewModel.isActionsPresented {
                                    viewModel.selectedItemID = item.persistentModelID
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
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

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: ClipboardStyle.sectionHeaderHeight)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(viewModel.emptyStateMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
