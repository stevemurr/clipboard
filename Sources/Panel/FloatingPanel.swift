import AppKit
import QuickLookUI

/// Borderless floating panel hosting the SwiftUI history UI.
///
/// The Quick Look control overrides live here (not on the SwiftUI content):
/// when QLPreviewPanel looks for a controller it walks the key window's
/// responder chain, and the first responder inside an NSHostingView is a
/// private SwiftUI view that never accepts control — the window itself is
/// always in its own chain.
final class FloatingPanel: NSPanel {
    var quickLookController: QuickLookController?
    var onCancel: (() -> Void)?

    // Borderless windows refuse key status without this.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClipboardStyle.panelWidth,
                height: ClipboardStyle.panelHeight
            ),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false // hiding is decided in windowDidResignKey
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear // SwiftUI draws the rounded material chrome
        hasShadow = true
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        self.contentView = contentView
    }

    // Esc backstop; normally the key monitor handles it first.
    override func cancelOperation(_ sender: Any?) {
        if let onCancel {
            onCancel()
        } else {
            orderOut(nil)
        }
    }

    // MARK: - Quick Look panel control

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = quickLookController
        panel.delegate = quickLookController
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}
