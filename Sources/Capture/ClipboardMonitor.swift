import AppKit

/// NSPasteboard has no change notifications, so this polls `changeCount`
/// every 0.5s and captures new content when it moves.
@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    private let onCapture: (CapturedContent, SourceApp?) -> Void

    init(onCapture: @escaping (CapturedContent, SourceApp?) -> Void) {
        self.onCapture = onCapture
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        // .common so ticks keep firing while our menus/panel track events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called after we write to the pasteboard ourselves so the next tick
    /// doesn't re-capture our own copy.
    func markSelfWrite() {
        lastChangeCount = pasteboard.changeCount
    }

    private func tick() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        let source = NSWorkspace.shared.frontmostApplication.map {
            SourceApp(bundleID: $0.bundleIdentifier, name: $0.localizedName)
        }

        guard let content = PasteboardClassifier.classify(pasteboard) else { return }

        // Contents swapped mid-read (fast repeated copies): discard and let
        // the next tick capture the settled state.
        guard pasteboard.changeCount == changeCount else { return }

        onCapture(content, source)
    }
}
