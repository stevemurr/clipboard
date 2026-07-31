import SwiftUI

struct DetailPaneView: View {
    @Environment(HistoryStore.self) private var store
    let item: ClipboardItem?

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                HStack {
                    Text("Preview")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(item.previewTypeLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.065), in: Capsule())
                        .accessibilityIdentifier("preview-type")
                }
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 16)
                .frame(height: ClipboardStyle.sectionHeaderHeight)

                preview(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(item.contentHash)
                    .transition(.opacity)

                Divider().opacity(0.65)

                InformationTableView(
                    item: item,
                    detailText: metadataDetail(for: item)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("preview-pane")
        } else {
            Text("No Selection")
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func preview(for item: ClipboardItem) -> some View {
        switch item.itemKind {
        case .text:
            if item.subtype == .color, let color = ColorParser.color(from: item.textContent ?? "") {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: color))
                        .frame(width: 140, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.separator, lineWidth: 1)
                        )
                    Text(item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else if let richPreview = item.richTextPreviewKind {
                richTextPreview(richPreview, source: item.textContent ?? "")
            } else if let source = item.textContent, let language = item.codeLanguage {
                CodePreviewView(source: source, language: language)
            } else {
                ScrollView {
                    Text(item.textContent ?? "")
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
            }
        case .image:
            if let filename = item.imagePath {
                ImagePreviewView(url: store.imageStore.url(forFilename: filename))
            } else {
                PreviewUnavailableView(
                    symbol: "photo.badge.exclamationmark",
                    title: "Preview unavailable",
                    message: "The stored image could not be found."
                )
            }
        case .file:
            switch PreviewFileKind.resolve(paths: item.fileURLPaths) {
            case .image:
                if let path = item.fileURLPaths.first {
                    ImagePreviewView(url: URL(fileURLWithPath: path))
                }
            case .code(let language):
                if let path = item.fileURLPaths.first {
                    CodeFilePreviewView(
                        url: URL(fileURLWithPath: path),
                        language: language
                    )
                }
            case .markdown:
                if let path = item.fileURLPaths.first {
                    MarkdownFilePreviewView(url: URL(fileURLWithPath: path))
                }
            case .other:
                switch LocalMediaPreviewKind.resolve(paths: item.fileURLPaths) {
                case .audio:
                    if let path = item.fileURLPaths.first {
                        AudioFilePreviewView(url: URL(fileURLWithPath: path))
                    }
                case .pdf:
                    if let path = item.fileURLPaths.first {
                        PDFFilePreviewView(url: URL(fileURLWithPath: path))
                    }
                case nil:
                    fileSummary(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func richTextPreview(
        _ kind: RichTextPreviewKind,
        source: String
    ) -> some View {
        switch kind {
        case .markdown:
            MarkdownPreviewView(markdown: source)
        case .youtube(let link):
            YouTubePreviewView(link: link)
        case .link(let url):
            RichLinkPreviewView(url: url)
        }
    }

    private func fileSummary(for item: ClipboardItem) -> some View {
        VStack(spacing: 10) {
            if let path = item.fileURLPaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
            }
            ForEach(item.fileURLPaths.prefix(4), id: \.self) { path in
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if item.fileURLPaths.count > 4 {
                Text("+\(item.fileURLPaths.count - 4) more")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private func metadataDetail(for item: ClipboardItem) -> String? {
        switch item.itemKind {
        case .image:
            guard let width = item.pixelWidth, let height = item.pixelHeight else {
                return "PNG"
            }
            return "\(width) × \(height) · PNG"

        case .text:
            let text = item.textContent ?? ""
            let lineCount = text.reduce(into: 1) { count, character in
                if character == "\n" { count += 1 }
            }

            if let richPreview = item.richTextPreviewKind {
                switch richPreview {
                case .markdown:
                    return "\(lineCount) \(lineCount == 1 ? "line" : "lines")"
                case .youtube(let link):
                    return "youtube.com · \(link.videoID)"
                case .link(let url):
                    return url.host ?? "Web link"
                }
            }
            if item.codeLanguage != nil || lineCount > 1 {
                return "\(lineCount) \(lineCount == 1 ? "line" : "lines")"
            }
            return nil

        case .file:
            guard let path = item.fileURLPaths.first else { return nil }
            switch PreviewFileKind.resolve(paths: item.fileURLPaths) {
            case .image:
                let format = URL(fileURLWithPath: path).pathExtension.uppercased()
                return format.isEmpty ? "Image file" : "\(format) image"
            case .code:
                return URL(fileURLWithPath: path).lastPathComponent
            case .markdown:
                return URL(fileURLWithPath: path).lastPathComponent
            case .other:
                switch LocalMediaPreviewKind.resolve(paths: item.fileURLPaths) {
                case .audio:
                    let format = URL(fileURLWithPath: path).pathExtension.uppercased()
                    return format.isEmpty ? "Audio file" : "\(format) audio"
                case .pdf:
                    return "PDF document"
                case nil:
                    break
                }
                let count = item.fileURLPaths.count
                return "\(count) \(count == 1 ? "file" : "files")"
            }
        }
    }
}
