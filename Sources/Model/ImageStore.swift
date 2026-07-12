import AppKit
import Foundation

/// Stores captured images as PNG files on disk. Keeping them as real files
/// (rather than blobs) lets Quick Look preview them directly.
@MainActor
final class ImageStore {
    let directory: URL
    private let thumbnails = NSCache<NSString, NSImage>()

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Writes PNG data and returns the filename to persist on the model.
    func write(pngData: Data) throws -> String {
        let filename = UUID().uuidString + ".png"
        try pngData.write(to: directory.appendingPathComponent(filename))
        return filename
    }

    func url(forFilename filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func image(forFilename filename: String) -> NSImage? {
        if let cached = thumbnails.object(forKey: filename as NSString) { return cached }
        guard let image = NSImage(contentsOf: url(forFilename: filename)) else { return nil }
        thumbnails.setObject(image, forKey: filename as NSString)
        return image
    }

    func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(forFilename: filename))
        thumbnails.removeObject(forKey: filename as NSString)
    }

    func deleteAll() {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in contents { try? fm.removeItem(at: url) }
        }
        thumbnails.removeAllObjects()
    }

    /// Removes image files left behind by crashes (files no row references).
    func sweepOrphans(keeping filenames: Set<String>) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in contents where !filenames.contains(url.lastPathComponent) {
            try? fm.removeItem(at: url)
        }
    }
}
