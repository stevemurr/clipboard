import SwiftUI

struct SearchBarView: View {
    @Bindable var viewModel: AppViewModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type to filter entries…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused(focus)
                .accessibilityIdentifier("search-field")

            Picker("", selection: $viewModel.typeFilter) {
                ForEach(TypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("type-filter")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
