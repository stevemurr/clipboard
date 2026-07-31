import PDFKit
import SwiftUI

struct PDFFilePreviewView: View {
    let url: URL

    @State private var phase: Phase = .loading
    @State private var pageIndex = 0

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("preview-pdf-loading")

            case .loaded(let payload):
                pdfCard(payload: payload)

            case .tooLarge:
                PreviewUnavailableView(
                    symbol: "doc.badge.ellipsis",
                    title: "PDF is too large to preview",
                    message: "Open the file to view the complete document."
                )
                .accessibilityIdentifier("preview-pdf-too-large")

            case .unavailable:
                PreviewUnavailableView(
                    symbol: "doc.badge.exclamationmark",
                    title: "Preview unavailable",
                    message: "The PDF is missing or could not be decoded."
                )
                .accessibilityIdentifier("preview-pdf-unavailable")
            }
        }
        .task(id: url) {
            pageIndex = 0
            phase = .loading

            switch await PDFPreviewLoader.load(url: url) {
            case .loaded(let payload):
                guard !Task.isCancelled else { return }
                phase = .loaded(payload)
            case .tooLarge:
                guard !Task.isCancelled else { return }
                phase = .tooLarge
            case .unavailable:
                guard !Task.isCancelled else { return }
                phase = .unavailable
            }
        }
    }

    private func pdfCard(payload: PDFPreviewPayload) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 11, weight: .bold))

                Text(payload.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Text(Self.byteString(payload.fileSize))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.78))

                if payload.document.pageCount > 1 {
                    Button {
                        pageIndex = max(pageIndex - 1, 0)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex == 0)
                    .accessibilityLabel("Previous PDF page")

                    Text("\(pageIndex + 1) of \(payload.document.pageCount)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .frame(minWidth: 42)
                        .accessibilityIdentifier("preview-pdf-page-status")

                    Button {
                        pageIndex = min(
                            pageIndex + 1,
                            payload.document.pageCount - 1
                        )
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex >= payload.document.pageCount - 1)
                    .accessibilityLabel("Next PDF page")
                }
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 36)

            Divider().overlay(Color.clipboardSeparator.opacity(0.72))

            PDFDocumentCanvas(
                document: payload.document,
                pageIndex: $pageIndex
            )
            .accessibilityIdentifier("preview-pdf-document")
        }
        .background(Color.primary.opacity(0.028))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.clipboardSeparator.opacity(0.80), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview-pdf")
        .padding(12)
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private enum Phase {
        case loading
        case loaded(PDFPreviewPayload)
        case tooLarge
        case unavailable
    }
}

private struct PDFDocumentCanvas: NSViewRepresentable {
    let document: PDFDocument
    @Binding var pageIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(pageIndex: $pageIndex)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.setAccessibilityElement(true)
        pdfView.setAccessibilityRole(.group)
        pdfView.setAccessibilityLabel("PDF document preview")
        pdfView.setAccessibilityIdentifier("preview-pdf-document")
        pdfView.backgroundColor = .clear
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.displayBox = .cropBox
        pdfView.displaysPageBreaks = false
        pdfView.document = document
        context.coordinator.observe(pdfView)
        goToRepresentedPage(in: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.pageIndex = $pageIndex
        if pdfView.document !== document {
            pdfView.document = document
        }

        guard let currentPage = pdfView.currentPage else {
            goToRepresentedPage(in: pdfView)
            return
        }

        if document.index(for: currentPage) != pageIndex {
            goToRepresentedPage(in: pdfView)
        }
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
        pdfView.document = nil
    }

    private func goToRepresentedPage(in pdfView: PDFView) {
        guard pageIndex >= 0,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex)
        else {
            return
        }
        pdfView.go(to: page)
    }

    final class Coordinator: NSObject {
        var pageIndex: Binding<Int>
        private weak var pdfView: PDFView?
        private var observer: NSObjectProtocol?

        init(pageIndex: Binding<Int>) {
            self.pageIndex = pageIndex
        }

        func observe(_ pdfView: PDFView) {
            stopObserving()
            self.pdfView = pdfView
            observer = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                guard let self,
                      let pdfView = self.pdfView,
                      let document = pdfView.document,
                      let page = pdfView.currentPage
                else {
                    return
                }

                let index = document.index(for: page)
                guard index != NSNotFound, self.pageIndex.wrappedValue != index else {
                    return
                }
                self.pageIndex.wrappedValue = index
            }
        }

        func stopObserving() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            pdfView = nil
        }

        deinit {
            stopObserving()
        }
    }
}

private struct PDFPreviewPayload: @unchecked Sendable {
    let document: PDFDocument
    let title: String
    let fileSize: Int64
}

private enum PDFPreviewLoadResult: @unchecked Sendable {
    case loaded(PDFPreviewPayload)
    case tooLarge
    case unavailable
}

private enum PDFPreviewLoader {
    /// Keeps file I/O and PDF parsing predictable inside the transient drawer.
    private static let maximumBytes = 64 * 1_024 * 1_024

    static func load(url: URL) async -> PDFPreviewLoadResult {
        let task = Task.detached(priority: .userInitiated) { () -> PDFPreviewLoadResult in
            guard url.isFileURL else { return .unavailable }

            do {
                try Task.checkCancellation()
                let values = try url.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey]
                )
                guard values.isRegularFile == true else { return .unavailable }

                if let fileSize = values.fileSize, fileSize > maximumBytes {
                    return .tooLarge
                }

                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
                try Task.checkCancellation()
                guard data.count <= maximumBytes else { return .tooLarge }
                guard !data.isEmpty, let document = PDFDocument(data: data),
                      document.pageCount > 0
                else {
                    return .unavailable
                }
                try Task.checkCancellation()

                let metadataTitle = document.documentAttributes?[
                    PDFDocumentAttribute.titleAttribute
                ] as? String
                let trimmedTitle = metadataTitle?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let title = trimmedTitle?.isEmpty == false
                    ? trimmedTitle!
                    : url.lastPathComponent

                return .loaded(
                    PDFPreviewPayload(
                        document: document,
                        title: title,
                        fileSize: Int64(values.fileSize ?? data.count)
                    )
                )
            } catch {
                return .unavailable
            }
        }

        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
