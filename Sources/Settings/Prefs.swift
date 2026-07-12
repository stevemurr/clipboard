import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}

enum PrefKey {
    static let historyLimit = "historyLimit"
}
