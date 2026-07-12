import AppKit
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
    private var footerTitle: XCUIElement { app.staticTexts["footer-title"] }
    private var typeFilter: XCUIElement { app.popUpButtons["type-filter"] }

    // MARK: - Helpers

    private func seedPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    @discardableResult
    private func waitForRow(titled title: String, timeout: TimeInterval = 5) -> XCUIElement {
        let row = app.staticTexts[title]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "row '\(title)' never appeared")
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
        app.menuItems["Links"].click()

        XCTAssertTrue(waitForRow(titled: link).exists)
        let plainRow = app.staticTexts[plain]
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: plainRow)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "non-link row still visible with Links filter")
    }

    func testCommandKTogglesQuickLook() {
        let text = uniqueText("quicklook")
        seedPasteboard(text)
        waitForRow(titled: text)

        let baseline = app.windows.count
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount({ $0 > baseline }),
                      "Quick Look panel did not open on ⌘K")

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount({ $0 <= baseline }),
                      "Quick Look panel did not close on second ⌘K")
        XCTAssertTrue(searchField.exists, "history panel should stay open after Quick Look closes")
    }
}
