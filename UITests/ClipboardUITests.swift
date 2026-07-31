import AppKit
import CoreGraphics
import XCTest

/// UI tests drive the real panel with synthesized keyboard events.
///
/// The app is launched with `--uitest`, which points it at a throwaway
/// store directory and opens the history panel at launch. Tests seed the
/// system pasteboard directly (NSPasteboard) and wait for the app's 0.5s
/// monitor to ingest, so they exercise the full capture → list → copy loop.
///
/// Note: these tests intentionally overwrite the system clipboard.
final class ClipboardUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()
        app.activate()
        if !searchField.waitForExistence(timeout: 5) {
            app.activate() // launch can race the previous test's teardown
            XCTAssertTrue(searchField.waitForExistence(timeout: 5), "history panel did not appear")
        }
    }

    override func tearDown() {
        app.terminate()
    }

    // MARK: - Elements

    private var searchField: XCUIElement { app.textFields["search-field"] }
    private var footerTitle: XCUIElement { app.descendants(matching: .any)["footer-title"] }
    private var typeFilter: XCUIElement { app.popUpButtons["type-filter"] }
    private var previewPane: XCUIElement {
        app.descendants(matching: .any)["preview-pane"]
    }

    // MARK: - Helpers

    private func seedPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func seedImagePasteboard(width: Int = 96, height: Int = 64) throws {
        let representation = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: representation))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSColor.systemBlue.withAlphaComponent(0.86).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 8, y: 8, width: 52, height: 48),
            xRadius: 10,
            yRadius: 10
        ).fill()
        NSColor.systemPink.withAlphaComponent(0.76).setFill()
        NSBezierPath(ovalIn: NSRect(x: 48, y: 12, width: 40, height: 40)).fill()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let png = try XCTUnwrap(
            representation.representation(using: .png, properties: [:])
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
    }

    private func seedFilePasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([url as NSURL]))
    }

    private func makeAudioFile() throws -> URL {
        let sampleRate: UInt32 = 8_000
        let sampleCount = Int(sampleRate / 2)
        let bytesPerSample: UInt16 = 2
        let dataSize = UInt32(sampleCount) * UInt32(bytesPerSample)
        var data = Data()

        data.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(UInt32(36) + dataSize, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(sampleRate * UInt32(bytesPerSample), to: &data)
        appendLittleEndian(bytesPerSample, to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        appendLittleEndian(dataSize, to: &data)

        for index in 0..<sampleCount {
            let sample = sin(2 * .pi * 440 * Double(index) / Double(sampleRate))
            appendLittleEndian(Int16(sample * 8_000), to: &data)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-preview-\(UUID().uuidString).wav")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makePDFFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-preview-\(UUID().uuidString).pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let context = try XCTUnwrap(
            CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        )

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.textBackgroundColor.cgColor)
        context.fill(mediaBox)
        context.setFillColor(NSColor.controlAccentColor.cgColor)
        context.fill(CGRect(x: 64, y: 650, width: 300, height: 28))
        context.endPDFPage()
        context.closePDF()
        return url
    }

    private func appendLittleEndian<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) {
            data.append(contentsOf: $0)
        }
    }

    private func openPreviewDrawer() {
        guard !previewPane.exists else { return }
        app.typeKey("p", modifierFlags: .command)
        XCTAssertTrue(
            previewPane.waitForExistence(timeout: 3),
            "preview drawer did not open on ⌘P"
        )
    }

    private func waitForPanelWidth(
        _ expectedWidth: CGFloat,
        accuracy: CGFloat = 3,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let dialog = app.dialogs.firstMatch
            let panel = dialog.exists ? dialog : app.windows.firstMatch
            guard panel.exists else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                continue
            }
            let width = panel.frame.width
            if abs(width - expectedWidth) <= accuracy {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    @discardableResult
    private func waitForRow(titled title: String, timeout: TimeInterval = 5) -> XCUIElement {
        let row = app.descendants(matching: .any)
            .matching(identifier: "history-row")
            .matching(NSPredicate(format: "label == %@ OR value == %@", title, title))
            .firstMatch
        let appeared = row.waitForExistence(timeout: timeout)
        if !appeared {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Missing history row"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        let pasteboardValue = NSPasteboard.general.string(forType: .string) ?? "<nil>"
        XCTAssertTrue(appeared, "row '\(title)' never appeared; pasteboard='\(pasteboardValue)'")
        return row
    }

    private func waitForPasteboard(toEqual expected: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSPasteboard.general.string(forType: .string) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func waitForWindowCount(_ predicate: @escaping (Int) -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(app.windows.count) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func uniqueText(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8))"
    }

    // MARK: - Tests

    func testPanelShowsSearchFieldAndFooter() {
        XCTAssertTrue(searchField.exists)
        XCTAssertTrue(footerTitle.exists)
        XCTAssertTrue(typeFilter.exists)
        XCTAssertTrue(app.buttons["footer-preview"].exists)
        XCTAssertFalse(previewPane.exists, "preview drawer should start closed")
        XCTAssertTrue(waitForPanelWidth(824))
    }

    func testCommandPTogglesPreviewDrawerAndWindowWidth() {
        let text = uniqueText("drawer")
        seedPasteboard(text)
        waitForRow(titled: text)

        XCTAssertFalse(previewPane.exists)
        XCTAssertTrue(waitForPanelWidth(824))

        app.typeKey("p", modifierFlags: .command)
        XCTAssertTrue(previewPane.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForPanelWidth(1040))
        XCTAssertTrue(searchField.exists)

        app.typeKey("p", modifierFlags: .command)
        let drawerGone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: drawerGone,
            object: previewPane
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
        XCTAssertTrue(waitForPanelWidth(824))
        XCTAssertTrue(searchField.exists)
    }

    func testCopiedTextAppearsInHistory() {
        let text = uniqueText("capture")
        seedPasteboard(text)
        waitForRow(titled: text)
    }

    func testTypingFiltersEntries() {
        let alpha = uniqueText("alpha")
        let beta = uniqueText("beta")
        seedPasteboard(alpha)
        waitForRow(titled: alpha)
        seedPasteboard(beta)
        waitForRow(titled: beta)

        searchField.click()
        app.typeText("alpha")
        XCTAssertEqual(searchField.value as? String, "alpha", "typed text did not reach the search field")

        XCTAssertTrue(waitForRow(titled: alpha).exists)
        let betaRow = app.staticTexts[beta]
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: betaRow)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "filtered-out row is still visible")
    }

    func testReturnCopiesSelectedEntryAndClosesPanel() {
        // Seed FIRST, so it becomes the auto-selected row; seed SECOND so the
        // pasteboard no longer equals the selection. Return must restore it.
        let first = uniqueText("first")
        let second = uniqueText("second")
        seedPasteboard(first)
        waitForRow(titled: first)
        seedPasteboard(second)
        waitForRow(titled: second)

        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(waitForPasteboard(toEqual: first), "Return did not copy the selected entry")
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: searchField)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "panel did not close after Return")
    }

    func testKeypadEnterCopiesSelectedEntryAndClosesPanel() {
        let first = uniqueText("keypad-first")
        let second = uniqueText("keypad-second")
        seedPasteboard(first)
        waitForRow(titled: first)
        seedPasteboard(second)
        waitForRow(titled: second)

        app.typeKey(.enter, modifierFlags: [])

        XCTAssertTrue(waitForPasteboard(toEqual: first), "Keypad Enter did not copy the selected entry")
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: searchField)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "panel did not close after keypad Enter")
    }

    func testArrowKeysChangeSelection() {
        // Selection sticks to the first-seeded entry; ↑ must move it to the
        // newer entry above, and Return copies that one.
        let older = uniqueText("older")
        let newer = uniqueText("newer")
        seedPasteboard(older)
        waitForRow(titled: older)
        seedPasteboard(newer)
        waitForRow(titled: newer)

        app.typeKey(.upArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(waitForPasteboard(toEqual: newer), "↑ + Return did not copy the row above")
    }

    func testEscapeClosesPanel() {
        app.typeKey(.escape, modifierFlags: [])
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: searchField)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "panel did not close on Escape")
    }

    func testTypeFilterShowsOnlyLinks() {
        let link = "https://example.com/\(UUID().uuidString.prefix(8))"
        let plain = uniqueText("plain")
        seedPasteboard(link)
        waitForRow(titled: link)
        seedPasteboard(plain)
        waitForRow(titled: plain)

        typeFilter.click()
        let linksItem = app.menuItems["Links"]
        if !linksItem.waitForExistence(timeout: 3) {
            typeFilter.click() // popup can miss the first click while the panel settles
            XCTAssertTrue(linksItem.waitForExistence(timeout: 3), "type filter menu did not open")
        }
        linksItem.click()

        XCTAssertTrue(waitForRow(titled: link).exists)
        let plainRow = app.staticTexts[plain]
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: plainRow)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "non-link row still visible with Links filter")
    }

    func testTypeFilterWithStoredItemsShowsNoMatches() {
        let plain = uniqueText("plain-empty-state")
        seedPasteboard(plain)
        waitForRow(titled: plain)

        typeFilter.click()
        let imagesItem = app.menuItems["Images"]
        if !imagesItem.waitForExistence(timeout: 3) {
            typeFilter.click()
            XCTAssertTrue(imagesItem.waitForExistence(timeout: 3), "type filter menu did not open")
        }
        imagesItem.click()

        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No clipboard history yet"].exists)
    }

    func testCodeSnippetUsesSyntaxPreview() {
        let source = """
        import SwiftUI

        struct ClipboardPreview: View {
            let title = "Dynamic preview"
            var body: some View {
                Text(title)
            }
        }
        """
        seedPasteboard(source)
        waitForRow(titled: "import SwiftUI")
        openPreviewDrawer()

        let codePreview = app.descendants(matching: .any)["preview-code"]
        XCTAssertTrue(codePreview.waitForExistence(timeout: 3), "code preview did not appear")
        XCTAssertTrue(
            app.descendants(matching: .any)["preview-code-text"].waitForExistence(timeout: 3),
            "native selectable code surface did not appear"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "Swift"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Swift code preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testImageUsesRenderedPreview() throws {
        try seedImagePasteboard()
        waitForRow(titled: "Image (96×64)")
        openPreviewDrawer()

        XCTAssertTrue(
            app.images["preview-image"].waitForExistence(timeout: 5),
            "rendered image preview did not appear"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "Image"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Image preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testMarkdownUsesRenderedPreview() {
        let source = """
        # Preview drawer launch checklist

        Rich previews stay focused and fast.

        - Render Markdown natively
        - Load media only on demand
        """
        seedPasteboard(source)
        waitForRow(titled: "Preview drawer launch checklist")
        openPreviewDrawer()

        XCTAssertTrue(
            app.descendants(matching: .any)["preview-markdown"]
                .waitForExistence(timeout: 3),
            "rendered Markdown preview did not appear"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "Markdown"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Markdown preview drawer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testYouTubeLinkUsesRichPreview() {
        let url = "https://youtu.be/dQw4w9WgXcQ"
        seedPasteboard(url)
        waitForRow(titled: url)
        openPreviewDrawer()

        XCTAssertTrue(
            app.descendants(matching: .any)["preview-youtube"]
                .waitForExistence(timeout: 3),
            "YouTube preview did not appear"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "YouTube"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "YouTube preview drawer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testWebLinkUsesRichPreview() {
        let url = "https://example.com/clipboard-preview"
        seedPasteboard(url)
        waitForRow(titled: url)
        openPreviewDrawer()

        XCTAssertTrue(
            app.descendants(matching: .any)["preview-rich-link"]
                .waitForExistence(timeout: 3),
            "rich web link preview did not appear"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "Link"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Web link preview drawer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAudioFileUsesPlayablePreview() throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        seedFilePasteboard(url)
        waitForRow(titled: url.lastPathComponent)
        openPreviewDrawer()

        XCTAssertTrue(
            app.descendants(matching: .any)["preview-audio"]
                .waitForExistence(timeout: 5),
            "audio preview did not appear"
        )
        XCTAssertTrue(app.buttons["preview-audio-playback"].exists)
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "Audio"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Audio preview drawer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testPDFFileUsesDocumentPreview() throws {
        let url = try makePDFFile()
        defer { try? FileManager.default.removeItem(at: url) }
        seedFilePasteboard(url)
        waitForRow(titled: url.lastPathComponent)
        openPreviewDrawer()

        XCTAssertTrue(
            app.descendants(matching: .any)["preview-pdf"]
                .waitForExistence(timeout: 5),
            "PDF preview did not appear"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["preview-pdf-document"].exists
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["preview-type"].value as? String,
            "PDF"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "PDF preview drawer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCommandYTogglesQuickLook() {
        let text = uniqueText("quicklook")
        seedPasteboard(text)
        waitForRow(titled: text)

        let baseline = app.windows.count
        app.typeKey("y", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount({ $0 > baseline }),
                      "Quick Look panel did not open on ⌘Y")

        app.typeKey("y", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount({ $0 <= baseline }),
                      "Quick Look panel did not close on second ⌘Y")
        XCTAssertTrue(searchField.exists, "history panel should stay open after Quick Look closes")
    }

    func testEscapeDismissesActionsThenDrawerBeforeClosingPanel() {
        let text = uniqueText("actions")
        seedPasteboard(text)
        waitForRow(titled: text)
        openPreviewDrawer()

        searchField.click()
        searchField.typeKey("k", modifierFlags: .command)
        let copyAction = app.buttons["clipboard-action-copy"]
        XCTAssertTrue(copyAction.waitForExistence(timeout: 3), "Actions menu did not open on ⌘K")

        app.typeKey(.escape, modifierFlags: [])
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: copyAction)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed,
                       "Escape did not dismiss the Actions menu")
        XCTAssertTrue(searchField.waitForExistence(timeout: 1),
                      "first Escape closed the panel along with the Actions menu")
        XCTAssertTrue(previewPane.exists, "first Escape also closed the preview drawer")

        app.typeKey(.escape, modifierFlags: [])
        let drawerGone = NSPredicate(format: "exists == false")
        let drawerExpectation = XCTNSPredicateExpectation(
            predicate: drawerGone,
            object: previewPane
        )
        XCTAssertEqual(XCTWaiter.wait(for: [drawerExpectation], timeout: 3), .completed,
                       "second Escape did not close the preview drawer")
        XCTAssertTrue(searchField.exists, "second Escape also closed the panel")

        app.typeKey(.escape, modifierFlags: [])
        let panelGone = NSPredicate(format: "exists == false")
        let panelExpectation = XCTNSPredicateExpectation(predicate: panelGone, object: searchField)
        XCTAssertEqual(XCTWaiter.wait(for: [panelExpectation], timeout: 5), .completed,
                       "third Escape did not close the panel")
    }
}
