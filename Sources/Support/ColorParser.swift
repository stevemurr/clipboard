import AppKit

/// Parses copied color strings — `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`,
/// `rgb(r, g, b)` and `rgba(r, g, b, a)`. Used both to classify text as a
/// color and to render the swatch preview.
enum ColorParser {
    static func isColorString(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 40 else { return false }
        return color(from: trimmed) != nil
    }

    static func color(from string: String) -> NSColor? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { return hexColor(String(s.dropFirst())) }
        if s.lowercased().hasPrefix("rgb") { return rgbColor(s) }
        return nil
    }

    private static func hexColor(_ hex: String) -> NSColor? {
        guard hex.allSatisfy(\.isHexDigit) else { return nil }
        let expand: (String) -> String = { $0.map { "\($0)\($0)" }.joined() }
        let full: String
        switch hex.count {
        case 3: full = expand(hex) + "ff"
        case 4: full = expand(hex)
        case 6: full = hex + "ff"
        case 8: full = hex
        default: return nil
        }
        var value: UInt64 = 0
        guard Scanner(string: full).scanHexInt64(&value) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 24) & 0xFF) / 255,
            green: CGFloat((value >> 16) & 0xFF) / 255,
            blue: CGFloat((value >> 8) & 0xFF) / 255,
            alpha: CGFloat(value & 0xFF) / 255
        )
    }

    private static func rgbColor(_ string: String) -> NSColor? {
        guard let open = string.firstIndex(of: "("), string.hasSuffix(")") else { return nil }
        let inner = string[string.index(after: open)..<string.index(before: string.endIndex)]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }

        func channel(_ part: String) -> CGFloat? {
            if part.hasSuffix("%"), let v = Double(part.dropLast()) { return CGFloat(v / 100) }
            guard let v = Double(part) else { return nil }
            return CGFloat(min(max(v, 0), 255) / 255)
        }

        guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2]) else { return nil }
        var a: CGFloat = 1
        if parts.count == 4 {
            guard let alpha = Double(parts[3].hasSuffix("%") ? String(parts[3].dropLast()) : parts[3]) else { return nil }
            a = parts[3].hasSuffix("%") ? CGFloat(alpha / 100) : CGFloat(min(max(alpha, 0), 1))
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
