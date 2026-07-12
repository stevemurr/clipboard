import AppKit
import QuickLookUI

/// Local keyDown monitor that routes navigation keys while the search field
/// keeps focus. Handled keys return nil (swallowed — the caret never moves);
/// everything else falls through to the TextField so typing filters.
///
/// Also routes keys while the Quick Look panel is key: QLPreviewPanel
/// consumes ⌘-equivalents before its delegate sees them, so the monitor is
/// the only reliable interception point for ⌘K / arrows there.
@MainActor
final class PanelKeyMonitor {
    enum Action {
        case moveUp
        case moveDown
        case commit
        case cancel
        case quickLook
        case deleteEntry
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
            self?.handle(event) ?? event
        }
    }

    func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)

        if event.window === panel {
            switch event.keyCode {
            case 126: // ↑
                handler(.moveUp)
                return nil
            case 125: // ↓
                handler(.moveDown)
                return nil
            case 36 where mods.isEmpty, 76 where mods.isEmpty: // Return / keypad Enter
                handler(.commit)
                return nil
            case 53 where mods.isEmpty: // Esc
                handler(.cancel)
                return nil
            case 40 where mods == .command: // ⌘K
                handler(.quickLook)
                return nil
            case 51 where mods == .command: // ⌘⌫
                handler(.deleteEntry)
                return nil
            default:
                return event
            }
        }

        if isQuickLookWindow(event.window) {
            switch event.keyCode {
            case 126: // ↑ — selection sync reloads the preview
                handler(.moveUp)
                return nil
            case 125: // ↓
                handler(.moveDown)
                return nil
            case 36 where mods.isEmpty, 76 where mods.isEmpty:
                handler(.commit)
                return nil
            case 40 where mods == .command: // ⌘K toggles Quick Look closed
                handler(.quickLook)
                return nil
            default: // Esc falls through: Quick Look closes itself natively
                return event
            }
        }

        // Other windows (e.g. Settings) are none of our business.
        return event
    }

    private func isQuickLookWindow(_ window: NSWindow?) -> Bool {
        guard let window, QLPreviewPanel.sharedPreviewPanelExists() else { return false }
        return window === QLPreviewPanel.shared()
    }
}
