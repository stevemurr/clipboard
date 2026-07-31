import AppKit

/// Writes app-originated text with the same marker used by history copies so
/// ClipboardMonitor never ingests Clipboard's own auxiliary clipboard data.
@MainActor
enum ClipboardPasteboardWriter {
    @discardableResult
    static func writeString(
        _ string: String,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else { return false }
        pasteboard.setData(Data(), forType: PasteboardClassifier.selfMarker)
        return true
    }
}
