import AppKit
import SwiftData

/// Owns the SwiftData container and an in-memory snapshot of all items sorted
/// by `lastCopiedAt` descending. At clipboard-history scale (a few thousand
/// rows) filtering/grouping in memory is sub-millisecond, so SwiftData is
/// used purely for durability.
@MainActor
@Observable
final class HistoryStore {
    // The context does not strongly retain its container; dropping this
    // deallocates the store's SQLite connection and later inserts trap.
    private let container: ModelContainer
    private let context: ModelContext
    let imageStore: ImageStore

    private(set) var items: [ClipboardItem] = []

    /// Fired after any mutation so the view model can re-filter.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Fired after we write to the pasteboard (wired to ClipboardMonitor.markSelfWrite).
    @ObservationIgnored var onSelfWrite: (() -> Void)?

    private var historyLimit: Int {
        UserDefaults.standard.object(forKey: PrefKey.historyLimit) as? Int ?? 1000
    }

    init(storeDirectory: URL) throws {
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: storeDirectory.appendingPathComponent("History.store"))
        container = try ModelContainer(for: ClipboardItem.self, configurations: configuration)
        context = container.mainContext
        imageStore = ImageStore(directory: storeDirectory.appendingPathComponent("Images", isDirectory: true))

        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Ingest

    func ingest(_ content: CapturedContent, source: SourceApp?) {
        if let existing = items.first(where: { $0.contentHash == content.contentHash }) {
            existing.timesCopied += 1
            existing.lastCopiedAt = .now
            if let source {
                existing.sourceAppBundleID = source.bundleID
                existing.sourceAppName = source.name
            }
            save()
            resort()
            onChange?()
            return
        }

        let item: ClipboardItem
        switch content.payload {
        case .text(let string, let subtype):
            item = ClipboardItem(
                kind: .text,
                textSubtype: subtype,
                textContent: string,
                sourceAppBundleID: source?.bundleID,
                sourceAppName: source?.name,
                byteSize: content.byteSize,
                contentHash: content.contentHash
            )
        case .image(let png, let width, let height):
            guard let filename = try? imageStore.write(pngData: png) else { return }
            item = ClipboardItem(
                kind: .image,
                imagePath: filename,
                sourceAppBundleID: source?.bundleID,
                sourceAppName: source?.name,
                byteSize: content.byteSize,
                pixelWidth: width,
                pixelHeight: height,
                contentHash: content.contentHash
            )
        case .fileURLs(let urls):
            item = ClipboardItem(
                kind: .file,
                fileURLPaths: urls.map(\.path),
                sourceAppBundleID: source?.bundleID,
                sourceAppName: source?.name,
                byteSize: content.byteSize,
                contentHash: content.contentHash
            )
        }

        context.insert(item)
        save()
        items.insert(item, at: 0)
        prune()
        onChange?()
    }

    // MARK: - Copy out

    func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.itemKind {
        case .text:
            pasteboard.setString(item.textContent ?? "", forType: .string)
        case .image:
            if let filename = item.imagePath,
               let png = try? Data(contentsOf: imageStore.url(forFilename: filename)) {
                pasteboard.setData(png, forType: .png)
                if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            }
        case .file:
            let urls = item.fileURLPaths.map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }

        pasteboard.setData(Data(), forType: PasteboardClassifier.selfMarker)
        onSelfWrite?()

        item.timesCopied += 1
        item.lastCopiedAt = .now
        save()
        resort()
        onChange?()
    }

    // MARK: - Deletion & pruning

    func delete(_ item: ClipboardItem) {
        if let filename = item.imagePath { imageStore.delete(filename: filename) }
        context.delete(item)
        save()
        items.removeAll { $0 === item }
        onChange?()
    }

    func clearAll() {
        try? context.delete(model: ClipboardItem.self)
        save()
        imageStore.deleteAll()
        items = []
        onChange?()
    }

    /// Drops the oldest (by last use) items over the configured limit, so
    /// frequently re-copied entries survive.
    func prune() {
        let limit = historyLimit
        guard limit > 0, items.count > limit else { return }
        for item in items[limit...] {
            if let filename = item.imagePath { imageStore.delete(filename: filename) }
            context.delete(item)
        }
        save()
        items.removeSubrange(limit...)
        onChange?()
    }

    func sweepOrphanImages() {
        imageStore.sweepOrphans(keeping: Set(items.compactMap(\.imagePath)))
    }

    // MARK: - Private

    private func resort() {
        items.sort { $0.lastCopiedAt > $1.lastCopiedAt }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            NSLog("Clipboard: failed to save history: \(error)")
        }
    }
}
