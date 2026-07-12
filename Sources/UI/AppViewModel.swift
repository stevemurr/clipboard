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
        didSet { refilter() }
    }

    var typeFilter: TypeFilter = .all {
        didSet { refilter() }
    }

    var selectedItemID: PersistentIdentifier? {
        didSet {
            if selectedItemID != oldValue { onSelectionChange?(selectedItem) }
        }
    }

    private(set) var sections: [HistorySectionGroup] = []
    private(set) var visibleItems: [ClipboardItem] = []

    /// Bumped on every panel presentation; the view re-asserts search focus on change.
    private(set) var presentationToken = 0

    @ObservationIgnored var onSelectionChange: ((ClipboardItem?) -> Void)?

    init(store: HistoryStore) {
        self.store = store
        refilter()
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return nil }
        return visibleItems.first { $0.persistentModelID == selectedItemID }
    }

    func resetForPresentation() {
        searchText = ""
        typeFilter = .all
        selectedItemID = visibleItems.first?.persistentModelID
        presentationToken += 1
    }

    func refilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = store.items.filter { typeFilter.matches($0) && matches(query: query, item: $0) }

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

    func deleteSelection() {
        guard let item = selectedItem,
              let index = visibleItems.firstIndex(where: { $0 === item }) else { return }
        store.delete(item) // triggers onChange → refilter
        if !visibleItems.isEmpty {
            selectedItemID = visibleItems[min(index, visibleItems.count - 1)].persistentModelID
        }
    }

    private func matches(query: String, item: ClipboardItem) -> Bool {
        guard !query.isEmpty else { return true }
        if let text = item.textContent, text.localizedCaseInsensitiveContains(query) { return true }
        if item.fileURLPaths.contains(where: {
            URL(fileURLWithPath: $0).lastPathComponent.localizedCaseInsensitiveContains(query)
        }) { return true }
        if let appName = item.sourceAppName, appName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }
}
