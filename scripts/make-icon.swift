// Generates Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
//
// Draws the icon natively at every .iconset size (vector SF Symbol glyph, so
// small sizes stay crisp) and assembles the .icns with iconutil.

import AppKit

let iconsetSizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func drawIcon(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px) // 1pt == 1px

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.clear(CGRect(x: 0, y: 0, width: px, height: px))

    let s = CGFloat(px) / 1024

    // Apple macOS icon grid: 824×824 squircle centered on a 1024 canvas.
    let squircleRect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let squircle = NSBezierPath(roundedRect: squircleRect, xRadius: 185 * s, yRadius: 185 * s)

    // Baked-in soft drop shadow, like the system icon template.
    ctx.saveGraphicsState()
    let dropShadow = NSShadow()
    dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    dropShadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    dropShadow.shadowBlurRadius = 22 * s
    dropShadow.set()
    NSColor(srgbRed: 0.24, green: 0.24, blue: 0.62, alpha: 1).setFill()
    squircle.fill()
    ctx.restoreGraphicsState()

    // Indigo vertical gradient.
    let top = NSColor(srgbRed: 0.435, green: 0.463, blue: 0.965, alpha: 1) // #6F76F6
    let bottom = NSColor(srgbRed: 0.184, green: 0.173, blue: 0.573, alpha: 1) // #2F2C92
    NSGradient(colors: [top, bottom])!.draw(in: squircle, angle: -90)

    // Faint radial highlight in the upper half for depth.
    ctx.saveGraphicsState()
    squircle.addClip()
    let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.16),
        NSColor.white.withAlphaComponent(0.0),
    ])!
    highlight.draw(
        fromCenter: NSPoint(x: 512 * s, y: 860 * s), radius: 0,
        toCenter: NSPoint(x: 512 * s, y: 860 * s), radius: 700 * s,
        options: []
    )
    ctx.restoreGraphicsState()

    // Hairline inner border for definition against light backgrounds.
    ctx.saveGraphicsState()
    squircle.addClip()
    NSColor.white.withAlphaComponent(0.10).setStroke()
    squircle.lineWidth = 6 * s
    squircle.stroke()
    ctx.restoreGraphicsState()

    // Glyph: clipboard with list lines, white, slight lift shadow.
    // Two palette layers: list lines in indigo, clipboard body in white.
    let lineColor = NSColor(srgbRed: 0.24, green: 0.23, blue: 0.66, alpha: 1)
    let config = NSImage.SymbolConfiguration(pointSize: 420 * s, weight: .medium)
        .applying(.init(paletteColors: [lineColor, .white]))
    let symbol = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let glyphSize = symbol.size
    let glyphOrigin = NSPoint(
        x: 512 * s - glyphSize.width / 2,
        y: 512 * s - glyphSize.height / 2
    )
    ctx.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    glyphShadow.shadowOffset = NSSize(width: 0, height: -7 * s)
    glyphShadow.shadowBlurRadius = 14 * s
    glyphShadow.set()
    symbol.draw(in: NSRect(origin: glyphOrigin, size: glyphSize))
    ctx.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Assemble

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let resourcesDir = projectDir.appendingPathComponent("Resources")
let iconsetDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("Clipboard-\(ProcessInfo.processInfo.processIdentifier).iconset")

try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetDir) }

for (name, px) in iconsetSizes {
    try drawIcon(px: px).write(to: iconsetDir.appendingPathComponent("\(name).png"))
}

let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", icnsURL.path, iconsetDir.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}
print("Wrote \(icnsURL.path)")
