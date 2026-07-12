import AppKit

struct SourceApp {
    let bundleID: String?
    let name: String?
}

@MainActor
enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache.object(forKey: bundleID as NSString) { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(icon, forKey: bundleID as NSString)
        return icon
    }
}
