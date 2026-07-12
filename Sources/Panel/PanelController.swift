import AppKit
import QuickLookUI
import SwiftUI

/// Owns the floating panel: creation, show/hide, key routing, and the
/// close-on-blur behavior.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let viewModel: AppViewModel
    private let store: HistoryStore
    private let quickLook: QuickLookController
    private var keyMonitor: PanelKeyMonitor!

    init(viewModel: AppViewModel, store: HistoryStore, quickLook: QuickLookController) {
        self.viewModel = viewModel
        self.store = store
        self.quickLook = quickLook

        let rootView = HistoryPanelView(viewModel: viewModel).environment(store)
        panel = FloatingPanel(contentView: NSHostingView(rootView: rootView))
        super.init()

        panel.delegate = self
        panel.quickLookController = quickLook
        viewModel.onSelectionChange = { [weak self] item in
            self?.quickLook.refreshIfVisible(with: item)
        }
        keyMonitor = PanelKeyMonitor(panel: panel) { [weak self] action in
            self?.handle(action)
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        position()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        keyMonitor.install()
        // After makeKey so the focus assertion (triggered by the token bump)
        // lands while the window can actually take first responder.
        viewModel.resetForPresentation()
    }

    func hide() {
        guard panel.isVisible else { return }
        quickLook.close()
        keyMonitor.remove()
        panel.orderOut(nil) // accessory app with no windows → previous app reactivates
    }

    // MARK: - Key actions

    private func handle(_ action: PanelKeyMonitor.Action) {
        switch action {
        case .moveUp:
            viewModel.moveSelection(by: -1)
        case .moveDown:
            viewModel.moveSelection(by: 1)
        case .commit:
            if let item = viewModel.selectedItem {
                store.copyToPasteboard(item)
            }
            hide()
        case .cancel:
            quickLook.isVisible ? quickLook.close() : hide()
        case .quickLook:
            quickLook.toggle(for: viewModel.selectedItem)
        case .deleteEntry:
            viewModel.deleteSelection()
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Quick Look taking key status is part of our UI, not a blur.
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isKeyWindow { return }
        // UI tests churn app activation between cases; blur-hide would make
        // the panel vanish mid-test. Esc/Return close paths still run.
        if AppDependencies.isUITest { return }
        hide()
    }

    // MARK: - Private

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.06
        ))
    }
}
