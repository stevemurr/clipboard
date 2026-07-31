import AppKit
import XCTest
@testable import Clipboard

final class HashingRegressionTests: XCTestCase {
    func testFileURLHashUsesUnambiguousFraming() {
        let first = [
            URL(fileURLWithPath: "/a"),
            URL(fileURLWithPath: "/b\n/c"),
        ]
        let second = [
            URL(fileURLWithPath: "/a\n/b"),
            URL(fileURLWithPath: "/c"),
        ]

        XCTAssertNotEqual(Hashing.sha256(fileURLs: first), Hashing.sha256(fileURLs: second))
    }
}

final class PasteboardClassifierRegressionTests: XCTestCase {
    func testCorruptPNGFallsBackToValidText() throws {
        let pasteboard = NSPasteboard(name: .init("clipboard-tests-png-\(UUID().uuidString)"))
        pasteboard.declareTypes([.png, .string], owner: nil)
        pasteboard.setData(Data("not a png".utf8), forType: .png)
        pasteboard.setString("recoverable text", forType: .string)

        let content = try XCTUnwrap(PasteboardClassifier.classify(pasteboard))
        guard case .text(let text, let subtype) = content.payload else {
            return XCTFail("Expected the valid text flavor to be used")
        }
        XCTAssertEqual(text, "recoverable text")
        XCTAssertNil(subtype)
    }

    func testCorruptTIFFFallsBackToValidText() throws {
        let pasteboard = NSPasteboard(name: .init("clipboard-tests-tiff-\(UUID().uuidString)"))
        pasteboard.declareTypes([.tiff, .string], owner: nil)
        pasteboard.setData(Data("not a tiff".utf8), forType: .tiff)
        pasteboard.setString("recoverable text", forType: .string)

        let content = try XCTUnwrap(PasteboardClassifier.classify(pasteboard))
        guard case .text(let text, _) = content.payload else {
            return XCTFail("Expected the valid text flavor to be used")
        }
        XCTAssertEqual(text, "recoverable text")
    }

    func testJPEGOnlyPasteboardNormalizesToPNGImage() throws {
        let representation = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 3,
                pixelsHigh: 2,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        let jpeg = try XCTUnwrap(
            representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.9]
            )
        )
        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        let pasteboard = NSPasteboard(name: .init("clipboard-tests-jpeg-\(UUID().uuidString)"))
        pasteboard.declareTypes([jpegType], owner: nil)
        pasteboard.setData(jpeg, forType: jpegType)

        let content = try XCTUnwrap(PasteboardClassifier.classify(pasteboard))
        guard case .image(let png, let width, let height) = content.payload else {
            return XCTFail("Expected JPEG flavor to become an image payload")
        }
        XCTAssertEqual(width, 3)
        XCTAssertEqual(height, 2)
        XCTAssertNotNil(NSBitmapImageRep(data: png))
        XCTAssertEqual(content.byteSize, png.count)
    }
}

final class ColorParserRegressionTests: XCTestCase {
    func testRejectsUnknownRGBFunctionsAndMismatchedArity() {
        XCTAssertFalse(ColorParser.isColorString("rgbGarbage(1,2,3)"))
        XCTAssertFalse(ColorParser.isColorString("rgba(1,2,3)"))
        XCTAssertFalse(ColorParser.isColorString("rgb(1,2,3,0.5)"))
    }
}

final class CodeSnippetDetectorTests: XCTestCase {
    func testDetectsStructuredLanguages() {
        XCTAssertEqual(
            CodeSnippetDetector.detect(
                """
                import SwiftUI

                struct PreviewCard: View {
                    let title: String
                    var body: some View { Text(title) }
                }
                """
            ),
            .swift
        )
        XCTAssertEqual(
            CodeSnippetDetector.detect(#"{"name":"Clipboard","enabled":true}"#),
            .json
        )
        XCTAssertEqual(
            CodeSnippetDetector.detect(
                """
                interface Result {
                  title: string;
                }
                const selected: Result = { title: "Clipboard" };
                """
            ),
            .typescript
        )
        XCTAssertEqual(
            CodeSnippetDetector.detect(
                """
                def preview(value):
                    if value:
                        return value.strip()
                """
            ),
            .python
        )
        XCTAssertEqual(
            CodeSnippetDetector.detect(
                """
                SELECT title, created_at
                FROM clipboard_items
                WHERE kind = 'text';
                """
            ),
            .sql
        )
    }

    func testLeavesProseLinksAndColorsAsRegularText() {
        XCTAssertNil(CodeSnippetDetector.detect("Let me know when you select a time from the list."))
        XCTAssertNil(CodeSnippetDetector.detect("https://example.com/path?value=true"))
        XCTAssertNil(CodeSnippetDetector.detect("#FF8800"))
    }

    func testFencedAndFileExtensionLanguagesAreStable() {
        XCTAssertEqual(
            CodeSnippetDetector.detect(
                """
                ```rust
                fn main() {
                    println!("hello");
                }
                ```
                """
            ),
            .rust
        )
        XCTAssertEqual(CodeLanguage.from(fileExtension: "tsx"), .typescript)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "swift"), .swift)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "rb"), .generic)
        XCTAssertNil(CodeLanguage.from(fileExtension: "pages"))
    }
}

final class PreviewFileKindTests: XCTestCase {
    func testResolvesSingleImageCodeAndMarkdownFilesWithoutChangingMultiFileSummary() {
        XCTAssertEqual(PreviewFileKind.resolve(paths: ["/tmp/mock.png"]), .image)
        XCTAssertEqual(
            PreviewFileKind.resolve(paths: ["/tmp/ClipboardView.swift"]),
            .code(.swift)
        )
        XCTAssertEqual(
            PreviewFileKind.resolve(paths: ["/tmp/launch-plan.md"]),
            .markdown
        )
        XCTAssertEqual(
            PreviewFileKind.resolve(paths: ["/tmp/a.png", "/tmp/b.png"]),
            .other
        )
    }
}

final class LocalMediaPreviewKindTests: XCTestCase {
    func testResolvesSingleAudioAndPDFButLeavesOtherAndMultipleFilesGeneric() {
        XCTAssertEqual(
            LocalMediaPreviewKind.resolve(paths: ["/tmp/voice-note.mp3"]),
            .audio
        )
        XCTAssertEqual(
            LocalMediaPreviewKind.resolve(paths: ["/tmp/research.pdf"]),
            .pdf
        )
        XCTAssertNil(LocalMediaPreviewKind.resolve(paths: ["/tmp/mock.png"]))
        XCTAssertNil(
            LocalMediaPreviewKind.resolve(paths: ["/tmp/a.mp3", "/tmp/b.mp3"])
        )
    }
}

final class RichPreviewDetectorTests: XCTestCase {
    func testDetectsStructuredMarkdownAndKeepsPureFencedSourceAsCode() {
        let markdown = """
        # Preview drawer

        Rich previews stay focused and fast.

        - Render Markdown natively
        - Load media only on demand
        """
        XCTAssertTrue(MarkdownDetector.isMarkdown(markdown))
        XCTAssertEqual(RichTextPreviewKind.detect(markdown), .markdown)

        let fencedSource = """
        ```rust
        fn main() {
            println!("hello");
        }
        ```
        """
        XCTAssertFalse(MarkdownDetector.isMarkdown(fencedSource))
        XCTAssertNil(RichTextPreviewKind.detect(fencedSource))
        XCTAssertEqual(CodeSnippetDetector.detect(fencedSource), .rust)
    }

    func testLeavesOrdinaryProseAndIsolatedFormattingAsText() {
        XCTAssertFalse(MarkdownDetector.isMarkdown(
            "This is an ordinary paragraph.\nIt simply continues on another line."
        ))
        XCTAssertFalse(MarkdownDetector.isMarkdown(
            "Please use **care** when changing this value.\nThanks for checking."
        ))
        XCTAssertNil(RichTextPreviewKind.detect(
            "A useful link is https://example.com, but this whole value is prose."
        ))
    }

    func testRecognizesYouTubeShapesAndRejectsLookalikeHosts() throws {
        let expectedID = "dQw4w9WgXcQ"
        let urls = [
            "https://www.youtube.com/watch?v=\(expectedID)",
            "https://youtu.be/\(expectedID)",
            "https://youtube.com/shorts/\(expectedID)",
            "https://music.youtube.com/watch?v=\(expectedID)",
            "https://youtube.com/live/\(expectedID)",
            "https://youtube.com/embed/\(expectedID)",
        ]

        for rawURL in urls {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertEqual(YouTubeLink(url: url)?.videoID, expectedID, rawURL)
        }

        XCTAssertNil(
            YouTubeLink(url: try XCTUnwrap(
                URL(string: "https://notyoutube.com/watch?v=\(expectedID)")
            ))
        )
    }

    func testWholeValueWebLinks() {
        XCTAssertEqual(
            WebLinkDetector.detect("  https://example.com/path?q=1\n")?.host,
            "example.com"
        )
        XCTAssertNil(WebLinkDetector.detect(
            "Read https://example.com/path before continuing."
        ))
    }

    func testMarkdownSanitizerBlocksHTMLRemoteImagesAndUnsafeLinks() {
        let sanitized = MarkdownSanitizer.sanitizeDocument(
            """
            <script>alert("no")</script>
            ![tracking](https://example.com/pixel.png)
            <strong>Safe text</strong>
            """
        )
        XCTAssertFalse(sanitized.localizedCaseInsensitiveContains("script"))
        XCTAssertFalse(sanitized.contains("pixel.png"))
        XCTAssertTrue(sanitized.contains("[Image: tracking]"))
        XCTAssertTrue(sanitized.contains("Safe text"))

        let attributed = MarkdownSanitizer.inlineAttributedString(
            from: "[unsafe](javascript:alert(1)) [safe](https://example.com)"
        )
        let links = attributed.runs.compactMap(\.link)
        XCTAssertEqual(links, [URL(string: "https://example.com")!])
    }
}

final class PreviewImageSizingTests: XCTestCase {
    func testFitsLargeImagesAndLimitsTinyImageUpscaling() {
        XCTAssertEqual(
            PreviewImageSizing.fittedSize(
                source: CGSize(width: 1_600, height: 900),
                container: CGSize(width: 400, height: 300)
            ),
            CGSize(width: 400, height: 225)
        )
        XCTAssertEqual(
            PreviewImageSizing.fittedSize(
                source: CGSize(width: 96, height: 64),
                container: CGSize(width: 400, height: 300)
            ),
            CGSize(width: 192, height: 128)
        )
    }
}

final class ClipboardLayoutRegressionTests: XCTestCase {
    func testApprovedDrawerGeometry() {
        XCTAssertEqual(ClipboardStyle.panelWidth, 824)
        XCTAssertEqual(ClipboardStyle.expandedPanelWidth, 1040)
        XCTAssertEqual(ClipboardStyle.panelHeight, 512)
        XCTAssertEqual(ClipboardStyle.drawerHistoryWidth, 576)
        XCTAssertEqual(ClipboardStyle.previewDrawerWidth, 464)
        XCTAssertEqual(
            ClipboardStyle.drawerHistoryWidth + ClipboardStyle.previewDrawerWidth,
            ClipboardStyle.expandedPanelWidth
        )
        XCTAssertEqual(ClipboardStyle.historyRowHeight, 42)
    }
}

@MainActor
final class ClipboardMCPResponseBoundsRegressionTests: XCTestCase {
    func testSummaryTitleAndPreviewAreBoundedByUTF8Bytes() {
        let oversizedGrapheme = "a" + String(repeating: "\u{0301}", count: 600_000)
        let item = ClipboardItem(
            kind: .text,
            textContent: oversizedGrapheme,
            byteSize: oversizedGrapheme.utf8.count,
            contentHash: "oversized-summary"
        )

        let summary = ClipboardMCPItemSummary(item: item)

        XCTAssertLessThanOrEqual(
            summary.title.utf8.count,
            ClipboardMCPLimits.maximumTitleLength
        )
        XCTAssertLessThanOrEqual(
            summary.preview?.utf8.count ?? 0,
            ClipboardMCPLimits.maximumPreviewLength
        )
    }
}

@MainActor
final class UIStateRegressionTests: XCTestCase {
    func testTypeFilterWithStoredItemsUsesNoMatchesEmptyState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-empty-state-\(UUID().uuidString)", isDirectory: true)
        let store = try HistoryStore(storeDirectory: directory)
        let viewModel = AppViewModel(store: store)
        XCTAssertEqual(viewModel.emptyStateMessage, "No clipboard history yet")

        store.ingest(
            CapturedContent(
                payload: .text("plain text", nil),
                contentHash: "empty-state-text",
                byteSize: 10
            ),
            source: nil
        )
        viewModel.typeFilter = .images

        XCTAssertTrue(viewModel.visibleItems.isEmpty)
        XCTAssertEqual(viewModel.emptyStateMessage, "No matches")
    }

    func testSelfOwnedStringWriterCannotBeRecaptured() throws {
        let pasteboard = NSPasteboard(name: .init("clipboard-tests-self-write-\(UUID().uuidString)"))

        XCTAssertTrue(ClipboardPasteboardWriter.writeString("redacted diagnostics", to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "redacted diagnostics")
        XCTAssertNotNil(pasteboard.data(forType: PasteboardClassifier.selfMarker))
        XCTAssertNil(PasteboardClassifier.classify(pasteboard))
    }

    func testActionsReflectSelectionAndDismissWhenFiltering() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-actions-\(UUID().uuidString)", isDirectory: true)
        let store = try HistoryStore(storeDirectory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        store.ingest(
            CapturedContent(
                payload: .text("https://example.com", .link),
                contentHash: "actions-link",
                byteSize: 19
            ),
            source: nil
        )

        let viewModel = AppViewModel(store: store)
        XCTAssertEqual(viewModel.availableActions, [.copy, .open, .quickLook, .delete])

        viewModel.toggleActions()
        XCTAssertTrue(viewModel.isActionsPresented)

        viewModel.moveActionSelection(by: -1)
        XCTAssertEqual(viewModel.selectedAction, .delete)

        viewModel.searchText = "no match"
        XCTAssertFalse(viewModel.isActionsPresented)
        XCTAssertEqual(viewModel.actionsSelectionIndex, 0)
    }

    func testPreviewToggleRequiresSelectionAndResetsForPresentation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-preview-state-\(UUID().uuidString)", isDirectory: true)
        let emptyStore = try HistoryStore(storeDirectory: directory)
        var viewModel = AppViewModel(store: emptyStore)

        viewModel.togglePreview()
        XCTAssertFalse(viewModel.isPreviewPresented)

        emptyStore.ingest(
            CapturedContent(
                payload: .text("Preview selection", nil),
                contentHash: "preview-state",
                byteSize: 17
            ),
            source: nil
        )
        viewModel = AppViewModel(store: emptyStore)

        var callbackStates: [Bool] = []
        viewModel.onPreviewPresentationChange = { callbackStates.append($0) }
        viewModel.togglePreview()
        XCTAssertTrue(viewModel.isPreviewPresented)

        viewModel.searchText = "no match"
        XCTAssertNil(viewModel.selectedItem)
        viewModel.togglePreview()
        XCTAssertFalse(
            viewModel.isPreviewPresented,
            "an open drawer must remain closable after filtering removes the selection"
        )

        viewModel.searchText = ""
        viewModel.togglePreview()
        XCTAssertTrue(viewModel.isPreviewPresented)

        viewModel.resetForPresentation()
        XCTAssertFalse(viewModel.isPreviewPresented)
        XCTAssertEqual(callbackStates, [true, false, true, false])
    }
}

@MainActor
final class HistoryStorePasteboardRegressionTests: XCTestCase {
    func testMissingImageCopyDoesNotClearPasteboardOrRecordSuccess() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-copy-regression-\(UUID().uuidString)", isDirectory: true)
        let store = try HistoryStore(storeDirectory: directory)
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        defer {
            snapshot.restore(to: pasteboard)
            // Release the store before removing its SQLite files.
            withExtendedLifetime(store) {}
            try? FileManager.default.removeItem(at: directory)
        }

        store.ingest(
            CapturedContent(
                payload: .image(png: Data([0x89, 0x50, 0x4e, 0x47]), width: 1, height: 1),
                contentHash: "missing-image",
                byteSize: 4
            ),
            source: nil
        )
        let item = try XCTUnwrap(store.item(withContentHash: "missing-image"))
        let filename = try XCTUnwrap(item.imagePath)
        try FileManager.default.removeItem(at: store.imageStore.url(forFilename: filename))

        pasteboard.clearContents()
        pasteboard.setString("sentinel", forType: .string)
        var selfWriteCount = 0
        store.onSelfWrite = { selfWriteCount += 1 }

        XCTAssertFalse(store.copyToPasteboard(contentHash: "missing-image"))
        XCTAssertEqual(pasteboard.string(forType: .string), "sentinel")
        XCTAssertEqual(item.timesCopied, 1)
        XCTAssertEqual(selfWriteCount, 0)
    }
}

@MainActor
final class PanelKeyMonitorRoutingTests: XCTestCase {
    func testEscapeRoutesOnlyWhenUnmodified() {
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 53, modifierFlags: []),
            .cancel
        )
        XCTAssertNil(
            PanelKeyMonitor.action(forKeyCode: 53, modifierFlags: .command)
        )
        XCTAssertNil(
            PanelKeyMonitor.action(forKeyCode: 53, modifierFlags: .shift)
        )
    }

    func testBareArrowsNavigateButModifiedArrowsPassThrough() {
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 126, modifierFlags: []),
            .moveUp
        )
        XCTAssertNil(PanelKeyMonitor.action(forKeyCode: 126, modifierFlags: .shift))
        XCTAssertNil(PanelKeyMonitor.action(forKeyCode: 125, modifierFlags: .option))
        XCTAssertNil(PanelKeyMonitor.action(forKeyCode: 126, modifierFlags: .command))
    }

    func testKeypadEnterCommitsDespiteNumericPadTransportFlag() {
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 76, modifierFlags: .numericPad),
            .commit
        )
    }

    func testSyntheticEnterCharacterCommitsWithUnexpectedKeyCode() {
        XCTAssertEqual(
            PanelKeyMonitor.action(
                forKeyCode: 0,
                modifierFlags: .numericPad,
                charactersIgnoringModifiers: "\u{3}"
            ),
            .commit
        )
    }

    func testCommandShortcutsRouteToTheirDistinctActions() {
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 40, modifierFlags: .command),
            .toggleActions
        )
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 16, modifierFlags: .command),
            .quickLook
        )
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 35, modifierFlags: .command),
            .togglePreview
        )
        XCTAssertNil(
            PanelKeyMonitor.action(forKeyCode: 40, modifierFlags: [.command, .shift])
        )
        XCTAssertNil(
            PanelKeyMonitor.action(forKeyCode: 35, modifierFlags: [.command, .shift])
        )
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 36, modifierFlags: .command),
            .openSelected
        )
        XCTAssertEqual(
            PanelKeyMonitor.action(forKeyCode: 51, modifierFlags: .command),
            .deleteEntry
        )
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
