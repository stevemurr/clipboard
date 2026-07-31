import AppKit
import QuartzCore
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
    private var compactFrameOrigin: NSPoint?

    init(viewModel: AppViewModel, store: HistoryStore, quickLook: QuickLookController) {
        self.viewModel = viewModel
        self.store = store
        self.quickLook = quickLook

        let rootView = HistoryPanelView(viewModel: viewModel).environment(store)
        panel = FloatingPanel(contentView: NSHostingView(rootView: rootView))
        super.init()

        panel.delegate = self
        panel.quickLookController = quickLook
        panel.onCancel = { [weak self] in
            self?.handle(.cancel)
        }
        viewModel.onSelectionChange = { [weak self] item in
            self?.quickLook.refreshIfVisible(with: item)
        }
        viewModel.onActionRequested = { [weak self] action in
            self?.perform(action)
        }
        viewModel.onPreviewPresentationChange = { [weak self] isPresented in
            self?.setPreviewPresented(isPresented)
        }
        keyMonitor = PanelKeyMonitor(panel: panel) { [weak self] action in
            self?.handle(action)
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        // Each presentation starts in the approved compact geometry.
        viewModel.dismissPreview()
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
        viewModel.dismissActions()
        quickLook.close()
        keyMonitor.remove()
        panel.orderOut(nil) // accessory app with no windows → previous app reactivates
        viewModel.dismissPreview()
    }

    // MARK: - Key actions

    private func handle(_ action: PanelKeyMonitor.Action) {
        switch action {
        case .moveUp:
            if viewModel.isActionsPresented {
                viewModel.moveActionSelection(by: -1)
            } else {
                viewModel.moveSelection(by: -1)
            }
        case .moveDown:
            if viewModel.isActionsPresented {
                viewModel.moveActionSelection(by: 1)
            } else {
                viewModel.moveSelection(by: 1)
            }
        case .commit:
            if viewModel.isActionsPresented {
                viewModel.requestSelectedAction()
            } else {
                perform(.copy)
            }
        case .cancel:
            if viewModel.isActionsPresented {
                viewModel.dismissActions()
            } else if quickLook.isVisible {
                quickLook.close()
            } else if viewModel.isPreviewPresented {
                viewModel.dismissPreview()
            } else {
                hide()
            }
        case .quickLook:
            perform(.quickLook)
        case .deleteEntry:
            perform(.delete)
        case .toggleActions:
            viewModel.toggleActions()
        case .togglePreview:
            viewModel.togglePreview()
        case .openSelected:
            perform(.open)
        }
    }

    private func perform(_ action: ClipboardAction) {
        guard let item = viewModel.selectedItem else {
            viewModel.dismissActions()
            return
        }

        viewModel.dismissActions()

        switch action {
        case .copy:
            store.copyToPasteboard(item)
            hide()

        case .open:
            let urls: [URL]
            if let url = item.webURL {
                urls = [url]
            } else if item.itemKind == .file {
                urls = item.fileURLPaths.map { URL(fileURLWithPath: $0) }
            } else {
                return
            }

            guard !urls.isEmpty else { return }
            hide()
            urls.forEach { NSWorkspace.shared.open($0) }

        case .quickLook:
            quickLook.toggle(for: item)

        case .delete:
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

    private func setPreviewPresented(_ isPresented: Bool) {
        if isPresented {
            compactFrameOrigin = panel.frame.origin
        }

        let width = isPresented
            ? ClipboardStyle.expandedPanelWidth
            : ClipboardStyle.panelWidth
        let preferredOrigin = isPresented ? panel.frame.origin : compactFrameOrigin
        let targetFrame = constrainedFrame(
            width: width,
            preferredOrigin: preferredOrigin
        )
        if !isPresented {
            compactFrameOrigin = nil
        }

        guard panel.isVisible,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(targetFrame, display: panel.isVisible)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = ClipboardStyle.drawerAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func constrainedFrame(
        width: CGFloat,
        preferredOrigin: NSPoint?
    ) -> NSRect {
        var frame = panel.frame
        frame.size.width = width
        if let preferredOrigin {
            frame.origin = preferredOrigin
        }

        guard let visibleFrame = panel.screen?.visibleFrame ?? screenContainingPanel()?.visibleFrame else {
            return frame
        }

        // Preserve the left edge as the drawer opens. Shift only as much as
        // necessary to keep the expanded panel on its current display.
        frame.origin.x = min(frame.origin.x, visibleFrame.maxX - width)
        frame.origin.x = max(frame.origin.x, visibleFrame.minX)
        return frame
    }

    private func screenContainingPanel() -> NSScreen? {
        let midpoint = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { NSMouseInRect(midpoint, $0.frame, false) }
    }

    private func position() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2
        ))
    }
}
