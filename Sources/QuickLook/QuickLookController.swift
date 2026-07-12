import AppKit
import QuickLookUI

/// Data source + delegate for QLPreviewPanel. Shows one item at a time (the
/// current selection); selection changes while visible just reload the panel.
@MainActor
final class QuickLookController: NSObject {
    private let imageStore: ImageStore
    private let tempDirectory: URL
    private var currentURL: URL?
    private var textFileCache: [String: URL] = [:]

    init(imageStore: ImageStore) {
        self.imageStore = imageStore
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.stevemurr.clipboard", isDirectory: true)
            .appendingPathComponent("ql", isDirectory: true)
        super.init()
    }

    var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    func toggle(for item: ClipboardItem?) {
        if isVisible {
            QLPreviewPanel.shared().orderOut(nil)
            return
        }
        guard let item, let url = url(for: item) else { return }
        currentURL = url
        QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
    }

    func refreshIfVisible(with item: ClipboardItem?) {
        guard isVisible else { return }
        guard let item, let url = url(for: item) else { return }
        currentURL = url
        QLPreviewPanel.shared().reloadData()
    }

    func close() {
        if isVisible { QLPreviewPanel.shared().orderOut(nil) }
    }

    func purgeTempFiles() {
        try? FileManager.default.removeItem(at: tempDirectory)
        textFileCache = [:]
    }

    // MARK: - Item → URL

    private func url(for item: ClipboardItem) -> URL? {
        switch item.itemKind {
        case .image:
            return item.imagePath.map(imageStore.url(forFilename:))
        case .file:
            let existing = item.fileURLPaths
                .map { URL(fileURLWithPath: $0) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
            return existing ?? textFile(named: item.contentHash, contents: item.fileURLPaths.joined(separator: "\n"))
        case .text:
            guard let text = item.textContent else { return nil }
            return textFile(named: item.contentHash, contents: text)
        }
    }

    private func textFile(named name: String, contents: String) -> URL? {
        if let cached = textFileCache[name], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let url = tempDirectory.appendingPathComponent(name + ".txt")
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        textFileCache[name] = url
        return url
    }
}

// @preconcurrency: the protocols' requirements are nonisolated, but AppKit
// only calls them on the main thread.
extension QuickLookController: @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        currentURL.map { $0 as NSURL }
    }
}
