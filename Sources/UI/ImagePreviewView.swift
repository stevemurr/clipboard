import AppKit
import ImageIO
import SwiftUI

struct ImagePreviewView: View {
    let url: URL

    @State private var phase: Phase = .loading

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.028))

            switch phase {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("preview-image-loading")

            case .loaded(let payload):
                if payload.hasAlpha {
                    TransparencyGrid()
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                GeometryReader { geometry in
                    let size = PreviewImageSizing.fittedSize(
                        source: payload.image.size,
                        container: CGSize(
                            width: max(geometry.size.width - 30, 1),
                            height: max(geometry.size.height - 30, 1)
                        )
                    )

                    Image(nsImage: payload.image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: size.width, height: size.height)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Image preview")
                        .accessibilityIdentifier("preview-image")
                }

            case .unavailable:
                PreviewUnavailableView(
                    symbol: "photo.badge.exclamationmark",
                    title: "Preview unavailable",
                    message: "The image is missing or could not be decoded."
                )
                .accessibilityIdentifier("preview-image-unavailable")
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.72), lineWidth: 0.75)
        }
        .padding(12)
        .task(id: url) {
            phase = .loading
            if let payload = await PreviewImageLoader.load(url: url) {
                guard !Task.isCancelled else { return }
                phase = .loaded(payload)
            } else {
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }

    private enum Phase {
        case loading
        case loaded(PreviewImagePayload)
        case unavailable
    }
}

enum PreviewImageSizing {
    static func fittedSize(
        source: CGSize,
        container: CGSize,
        maximumUpscale: CGFloat = 2
    ) -> CGSize {
        guard source.width > 0, source.height > 0,
              container.width > 0, container.height > 0
        else { return .zero }

        let fitScale = min(
            container.width / source.width,
            container.height / source.height
        )
        let scale = min(fitScale, maximumUpscale)
        return CGSize(
            width: floor(source.width * scale),
            height: floor(source.height * scale)
        )
    }
}

private struct TransparencyGrid: View {
    private let tileSize: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))

            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(Color.primary.opacity(0.045))
                    )
                }
            }
        }
        .background(Color.primary.opacity(0.014))
        .accessibilityHidden(true)
    }
}

private struct PreviewImagePayload: @unchecked Sendable {
    let image: NSImage
    let hasAlpha: Bool
}

private enum PreviewImageLoader {
    private static let maximumPixelDimension = 1_800

    static func load(url: URL) async -> PreviewImagePayload? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            ) else {
                return nil
            }

            return PreviewImagePayload(
                image: NSImage(
                    cgImage: image,
                    size: NSSize(width: image.width, height: image.height)
                ),
                hasAlpha: image.hasAlphaChannel
            )
        }.value
    }
}

private extension CGImage {
    var hasAlphaChannel: Bool {
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            true
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        @unknown default:
            false
        }
    }
}
