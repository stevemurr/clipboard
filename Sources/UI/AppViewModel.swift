import Foundation
import SwiftData

struct HistorySectionGroup: Identifiable {
    let section: HistorySection
    let items: [ClipboardItem]
    var id: HistorySection { section }
}

@MainActor
@Observable
final class AppViewModel {
    private let store: HistoryStore

    var searchText: String = "" {
        didSet {
            dismissActions()
            refilter()
        }
    }

    var typeFilter: TypeFilter = .all {
        didSet {
            dismissActions()
            refilter()
        }
    }

    var selectedItemID: PersistentIdentifier? {
        didSet {
            if selectedItemID != oldValue {
                dismissActions()
                onSelectionChange?(selectedItem)
            }
        }
    }

    private(set) var sections: [HistorySectionGroup] = []
    private(set) var visibleItems: [ClipboardItem] = []
    private(set) var isActionsPresented = false
    private(set) var isPreviewPresented = false {
        didSet {
            guard isPreviewPresented != oldValue else { return }
            onPreviewPresentationChange?(isPreviewPresented)
        }
    }
    private(set) var actionsSelectionIndex = 0

    /// Bumped on every panel presentation; the view re-asserts search focus on change.
    private(set) var presentationToken = 0

    @ObservationIgnored var onSelectionChange: ((ClipboardItem?) -> Void)?
    @ObservationIgnored var onActionRequested: ((ClipboardAction) -> Void)?
    @ObservationIgnored var onPreviewPresentationChange: ((Bool) -> Void)?

    init(store: HistoryStore) {
        self.store = store
        refilter()
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return nil }
        return visibleItems.first { $0.persistentModelID == selectedItemID }
    }

    var emptyStateMessage: String {
        store.items.isEmpty ? "No clipboard history yet" : "No matches"
    }

    var availableActions: [ClipboardAction] {
        guard let item = selectedItem else { return [] }
        var actions: [ClipboardAction] = [.copy]
        if item.webURL != nil || item.itemKind == .file {
            actions.append(.open)
        }
        actions.append(contentsOf: [.quickLook, .delete])
        return actions
    }

    var selectedAction: ClipboardAction? {
        guard availableActions.indices.contains(actionsSelectionIndex) else { return nil }
        return availableActions[actionsSelectionIndex]
    }

    func resetForPresentation() {
        searchText = ""
        typeFilter = .all
        selectedItemID = visibleItems.first?.persistentModelID
        dismissActions()
        dismissPreview()
        presentationToken += 1
    }

    func refilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = store.items.filter { typeFilter.matches($0) && $0.matches(searchQuery: query) }

        // Input is sorted by lastCopiedAt desc, so sections emerge already
        // ordered and contiguous — one O(n) pass.
        let sectioner = DateSectioner()
        var groups: [HistorySectionGroup] = []
        var currentSection: HistorySection?
        var currentItems: [ClipboardItem] = []
        for item in filtered {
            let section = sectioner.section(for: item.lastCopiedAt)
            if section != currentSection {
                if let currentSection {
                    groups.append(HistorySectionGroup(section: currentSection, items: currentItems))
                }
                currentSection = section
                currentItems = []
            }
            currentItems.append(item)
        }
        if let currentSection {
            groups.append(HistorySectionGroup(section: currentSection, items: currentItems))
        }

        visibleItems = filtered
        sections = groups

        if selectedItemID == nil || !filtered.contains(where: { $0.persistentModelID == selectedItemID }) {
            selectedItemID = filtered.first?.persistentModelID
        }
    }

    func moveSelection(by delta: Int) {
        guard !visibleItems.isEmpty else { return }
        guard let currentIndex = visibleItems.firstIndex(where: { $0.persistentModelID == selectedItemID }) else {
            selectedItemID = visibleItems.first?.persistentModelID
            return
        }
        let newIndex = min(max(currentIndex + delta, 0), visibleItems.count - 1)
        selectedItemID = visibleItems[newIndex].persistentModelID
    }

    func toggleActions() {
        guard selectedItem != nil else { return }
        isActionsPresented.toggle()
        actionsSelectionIndex = 0
    }

    func dismissActions() {
        isActionsPresented = false
        actionsSelectionIndex = 0
    }

    func togglePreview() {
        // A selection is required to open the drawer, but never to close it.
        // Filtering can temporarily remove every visible item while the
        // drawer is already presented.
        guard isPreviewPresented || selectedItem != nil else { return }
        dismissActions()
        isPreviewPresented.toggle()
    }

    func dismissPreview() {
        isPreviewPresented = false
    }

    func moveActionSelection(by delta: Int) {
        let count = availableActions.count
        guard count > 0 else { return }
        actionsSelectionIndex = (actionsSelectionIndex + delta + count) % count
    }

    func selectAction(index: Int) {
        guard availableActions.indices.contains(index) else { return }
        actionsSelectionIndex = index
    }

    func requestAction(_ action: ClipboardAction) {
        guard availableActions.contains(action) else { return }
        onActionRequested?(action)
    }

    func requestSelectedAction() {
        guard let selectedAction else { return }
        requestAction(selectedAction)
    }

    func deleteSelection() {
        guard let item = selectedItem,
              let index = visibleItems.firstIndex(where: { $0 === item }) else { return }
        store.delete(item) // triggers onChange → refilter
        if !visibleItems.isEmpty {
            selectedItemID = visibleItems[min(index, visibleItems.count - 1)].persistentModelID
        }
    }
}
