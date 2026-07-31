import AppKit
import QuickLookUI

/// Local keyDown monitor that routes navigation keys while the search field
/// keeps focus. Handled keys return nil (swallowed — the caret never moves);
/// everything else falls through to the TextField so typing filters.
///
/// Also routes keys while the Quick Look panel is key: QLPreviewPanel
/// consumes ⌘-equivalents before its delegate sees them, so the monitor is
/// the only reliable interception point for ⌘Y / arrows there.
@MainActor
final class PanelKeyMonitor {
    enum Action: Equatable {
        case moveUp
        case moveDown
        case commit
        case cancel
        case quickLook
        case deleteEntry
        case toggleActions
        case togglePreview
        case openSelected
    }

    private weak var panel: NSPanel?
    private let handler: (Action) -> Void
    private var monitor: Any?

    init(panel: NSPanel, handler: @escaping (Action) -> Void) {
        self.panel = panel
        self.handler = handler
    }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.window === panel {
            guard let action = Self.action(
                forKeyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers
            ) else { return event }
            handler(action)
            return nil
        }

        if isQuickLookWindow(event.window) {
            switch Self.action(
                forKeyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers
            ) {
            case .moveUp, .moveDown, .commit, .quickLook:
                if let action = Self.action(
                    forKeyCode: event.keyCode,
                    modifierFlags: event.modifierFlags,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers
                ) {
                    handler(action)
                }
                return nil
            default: // Esc falls through: Quick Look closes itself natively.
                return event
            }
        }

        // Other windows (e.g. Settings) are none of our business.
        return event
    }

    /// Pure routing seam used by the event monitor and regression tests.
    /// `.numericPad` and `.function` describe where a key came from; they are
    /// not user intent modifiers like Shift, Option, Control, or Command.
    static func action(
        forKeyCode keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String? = nil
    ) -> Action? {
        let modifiers = modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        if modifiers.isEmpty,
           charactersIgnoringModifiers == "\r" || charactersIgnoringModifiers == "\u{3}" {
            return .commit
        }

        switch keyCode {
        case 126 where modifiers.isEmpty: return .moveUp
        case 125 where modifiers.isEmpty: return .moveDown
        case 36 where modifiers.isEmpty, 76 where modifiers.isEmpty: return .commit
        case 36 where modifiers == .command, 76 where modifiers == .command: return .openSelected
        case 53 where modifiers.isEmpty: return .cancel
        case 40 where modifiers == .command: return .toggleActions
        case 35 where modifiers == .command: return .togglePreview
        case 16 where modifiers == .command: return .quickLook
        case 51 where modifiers == .command: return .deleteEntry
        default: return nil
        }
    }

    private func isQuickLookWindow(_ window: NSWindow?) -> Bool {
        guard let window, QLPreviewPanel.sharedPreviewPanelExists() else { return false }
        return window === QLPreviewPanel.shared()
    }
}
