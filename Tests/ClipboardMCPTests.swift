import AppKit
import Foundation
import LocalMCPConsumer
import LocalMCPContracts
import LocalMCPDiscovery
import LocalMCPProducer
import LocalMCPTesting
import XCTest
@testable import Clipboard

final class ClipboardMCPCommandTests: XCTestCase {
    func testDefinitionsPublishBoundedContractsAndRegister() async throws {
        let search = ClipboardSearchCommandHandler.definition
        XCTAssertEqual(search.name, "clipboard.search")
        XCTAssertEqual(search.annotations, CommandAnnotations(
            readOnly: true,
            idempotent: true,
            destructive: false,
            openWorld: false
        ))
        XCTAssertEqual(search.inputSchema["properties"]?["query"]?["maxLength"], .integer(512))
        XCTAssertEqual(search.inputSchema["properties"]?["limit"]?["maximum"], .integer(100))
        XCTAssertEqual(
            search.inputSchema["properties"]?["kind"]?["enum"],
            .array([.string("text"), .string("image"), .string("file"), .string("link")])
        )
        XCTAssertEqual(search.inputSchema["required"], .array([.string("query")]))
        XCTAssertEqual(search.inputSchema["additionalProperties"], .bool(false))

        let get = ClipboardGetCommandHandler.definition
        XCTAssertEqual(get.name, "clipboard.get")
        XCTAssertEqual(get.annotations, CommandAnnotations(
            readOnly: true,
            idempotent: true,
            destructive: false,
            openWorld: false
        ))
        XCTAssertEqual(get.inputSchema["properties"]?["id"]?["maxLength"], .integer(128))
        XCTAssertEqual(get.inputSchema["required"], .array([.string("id")]))

        let copy = ClipboardCopyCommandHandler.definition
        XCTAssertEqual(copy.name, "clipboard.copy")
        XCTAssertEqual(copy.annotations, CommandAnnotations(
            readOnly: false,
            idempotent: false,
            destructive: true,
            openWorld: false
        ))
        XCTAssertEqual(copy.outputSchema?["required"], .array([
            .string("copied"), .string("id"), .string("title"),
        ]))

        // Registration validates the schemas and the typed handler signatures.
        let registry = CommandRegistry()
        try await registry.register(search) { (_: ClipboardMCPSearchInput, _: CommandContext) async throws in
            CommandResult.text("ok")
        }
        try await registry.register(get) { (_: ClipboardMCPGetInput, _: CommandContext) async throws in
            CommandResult.text("ok")
        }
        try await registry.register(copy) { (_: ClipboardMCPCopyInput, _: CommandContext) async throws in
            CommandResult.text("ok")
        }
    }

    func testSearchValidatesBoundsTrimsQueryAndAppliesDefaultLimit() async throws {
        let history = RecordingClipboardHistory()
        let handler = ClipboardSearchCommandHandler(history: history)

        _ = try await handler.call(
            input: .init(query: "  report  ", kind: .link),
            context: commandContext()
        )
        _ = try await handler.call(
            input: .init(query: String(repeating: "é", count: 512), limit: 100),
            context: commandContext()
        )

        await assertInvalidInput {
            try await handler.call(
                input: .init(query: String(repeating: "é", count: 513)),
                context: commandContext()
            )
        }
        for invalidLimit in [0, -1, 101, Int.max] {
            await assertInvalidInput {
                try await handler.call(
                    input: .init(query: "x", limit: invalidLimit),
                    context: commandContext()
                )
            }
        }

        let calls = await history.searchCalls
        XCTAssertEqual(calls, [
            HistorySearchCall(query: "report", kind: .link, limit: 25),
            HistorySearchCall(query: String(repeating: "é", count: 512), kind: nil, limit: 100),
        ])
    }

    func testGetAndCopyValidateIDsAndReturnGuidanceForUnknownIDs() async throws {
        let history = RecordingClipboardHistory()
        let get = ClipboardGetCommandHandler(history: history)
        let copy = ClipboardCopyCommandHandler(history: history)

        await assertInvalidInput {
            try await get.call(input: .init(id: ""), context: commandContext())
        }
        await assertInvalidInput {
            try await copy.call(
                input: .init(id: String(repeating: "a", count: 129)),
                context: commandContext()
            )
        }
        let itemLookups = await history.itemIDs
        let copyLookups = await history.copyIDs
        XCTAssertTrue(itemLookups.isEmpty)
        XCTAssertTrue(copyLookups.isEmpty)

        let missingGet = try await get.call(input: .init(id: "unknown"), context: commandContext())
        XCTAssertTrue(missingGet.isError)
        XCTAssertEqual(missingGet.text?.contains("clipboard.search"), true)

        let missingCopy = try await copy.call(input: .init(id: "unknown"), context: commandContext())
        XCTAssertTrue(missingCopy.isError)
        XCTAssertEqual(missingCopy.text?.contains("clipboard.search"), true)
    }

    private func assertInvalidInput(
        _ operation: () async throws -> CommandResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected invalid input", file: file, line: line)
        } catch let error as LocalMCPError {
            XCTAssertEqual(error, .invalidCommandInput, file: file, line: line)
        } catch {
            XCTFail("Unexpected error type", file: file, line: line)
        }
    }
}

@MainActor
final class ClipboardMCPBridgeTests: XCTestCase {
    func testBridgeSearchesGetsAndCopiesOverRealStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-mcp-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(storeDirectory: directory)
        let bridge = HistoryStoreMCPBridge(store: store)

        let longText = String(repeating: "a", count: ClipboardMCPLimits.maximumFullTextBytes + 1000)
        store.ingest(
            CapturedContent(payload: .text(longText, nil), contentHash: "hash-text", byteSize: longText.utf8.count),
            source: SourceApp(bundleID: "com.example.editor", name: "Example Editor")
        )
        store.ingest(
            CapturedContent(payload: .image(png: Data([0x89, 0x50, 0x4E, 0x47]), width: 4, height: 2), contentHash: "hash-image", byteSize: 4),
            source: nil
        )
        store.ingest(
            CapturedContent(payload: .fileURLs([URL(fileURLWithPath: "/tmp/Example Report.txt")]), contentHash: "hash-file", byteSize: 7),
            source: nil
        )

        // Newest first: ingestion order is text, image, file.
        let all = await bridge.search(query: "", kind: nil, limit: 25)
        XCTAssertEqual(all.map(\.id), ["hash-file", "hash-image", "hash-text"])

        let textOnly = await bridge.search(query: "", kind: .text, limit: 25)
        XCTAssertEqual(textOnly.map(\.id), ["hash-text"])
        XCTAssertEqual(textOnly.first?.sourceAppName, "Example Editor")
        XCTAssertEqual(textOnly.first?.preview?.count, ClipboardMCPLimits.maximumPreviewLength)

        let byAppName = await bridge.search(query: "Example Editor", kind: nil, limit: 25)
        XCTAssertEqual(byAppName.map(\.id), ["hash-text"])

        let textContent = await bridge.item(id: "hash-text")
        let text = try XCTUnwrap(textContent)
        XCTAssertEqual(text.kind, "text")
        XCTAssertEqual(text.textTruncated, true)
        XCTAssertEqual(text.text?.utf8.count, ClipboardMCPLimits.maximumFullTextBytes)

        let imageContent = await bridge.item(id: "hash-image")
        let image = try XCTUnwrap(imageContent)
        XCTAssertEqual(image.kind, "image")
        XCTAssertEqual(image.pixelWidth, 4)
        XCTAssertEqual(image.pixelHeight, 2)
        let imageURI = try XCTUnwrap(image.imageFileURI)
        XCTAssertTrue(imageURI.hasPrefix("file://"))

        let fileContent = await bridge.item(id: "hash-file")
        let file = try XCTUnwrap(fileContent)
        XCTAssertEqual(file.kind, "file")
        XCTAssertEqual(file.filePaths, ["/tmp/Example Report.txt"])

        let missing = await bridge.item(id: "missing")
        XCTAssertNil(missing)

        // Copying mutates the real system pasteboard; save and restore any
        // plain-text contents so the test stays polite on a developer machine.
        let pasteboard = NSPasteboard.general
        let savedText = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let savedText { pasteboard.setString(savedText, forType: .string) }
        }

        let copyReceipt = await bridge.copyItem(id: "hash-text")
        let receipt = try XCTUnwrap(copyReceipt)
        XCTAssertTrue(receipt.copied)
        XCTAssertEqual(receipt.id, "hash-text")
        XCTAssertEqual(pasteboard.string(forType: .string), longText)
        XCTAssertNotNil(pasteboard.data(forType: PasteboardClassifier.selfMarker))
        XCTAssertEqual(store.item(withContentHash: "hash-text")?.timesCopied, 2)
    }
}

final class ClipboardMCPLiveRuntimeTests: XCTestCase {
    @MainActor
    func testLiveRuntimeRegistersRestartsAndServesClipboardToolsOverHTTP() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-mcp-live-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(storeDirectory: directory)
        let seededText = "Quarterly numbers for the runtime test"
        store.ingest(
            CapturedContent(payload: .text(seededText, nil), contentHash: "hash-live-text", byteSize: seededText.utf8.count),
            source: SourceApp(bundleID: "com.example.editor", name: "Example Editor")
        )

        let catalog = DiscoveryCatalog()
        let producer = LocalMCPProducer(
            identity: ProducerIdentity(
                stableID: ClipboardMCPRuntimeFactory.producerID,
                displayName: "Clipboard",
                version: "1.0.0"
            ),
            instanceID: "0b0a4a6a-58ab-4c2f-9f6e-16f2b45f8f01",
            transport: LocalMCPHTTPProducerTransport(),
            // The catalog is the channel-binding-aware advertiser double;
            // Bonjour stays out of unit tests.
            advertiser: catalog,
            grantStore: InMemoryProducerGrantStore(),
            approval: RecordingPairingApprover(),
            random: SequenceRandomBytesGenerator(fallback: 40)
        )
        let runtime = LiveClipboardMCPRuntime(
            producer: producer,
            history: HistoryStoreMCPBridge(store: store)
        )

        do {
            try await runtime.start()
            try await exerciseLiveRuntime(
                catalog: catalog,
                store: store,
                seededText: seededText,
                randomFallback: 80,
                expectedTimesCopied: 2
            )
            await runtime.stop()
            let firstStoppedSnapshot = await catalog.snapshot()
            XCTAssertTrue(firstStoppedSnapshot.isEmpty)

            // Restarting the app-owned runtime must reuse the registered
            // commands rather than attempting a duplicate registration.
            try await runtime.start()
            try await exerciseLiveRuntime(
                catalog: catalog,
                store: store,
                seededText: seededText,
                randomFallback: 120,
                expectedTimesCopied: 3
            )
            await runtime.stop()
            let secondStoppedSnapshot = await catalog.snapshot()
            XCTAssertTrue(secondStoppedSnapshot.isEmpty)
        } catch {
            await runtime.stop()
            throw error
        }
    }

    @MainActor
    private func exerciseLiveRuntime(
        catalog: DiscoveryCatalog,
        store: HistoryStore,
        seededText: String,
        randomFallback: UInt8,
        expectedTimesCopied: Int
    ) async throws {
        let instances = await catalog.snapshot()
        let instance = try XCTUnwrap(instances.first)
        XCTAssertEqual(instances.count, 1)
        XCTAssertEqual(instance.identity.stableID, ClipboardMCPRuntimeFactory.producerID)

        let consumer = LocalMCPConsumer(
            instance: instance,
            identity: ConsumerIdentity(
                stableID: "com.example.clipboard-test-consumer",
                displayName: "Clipboard Test Consumer",
                version: "1.0.0",
                installationID: "9f2b0a2e-cf6c-4f6e-9a1f-1f6f4f0a2e42"
            ),
            connector: LocalMCPHTTPConnector(),
            grantStore: InMemoryConsumerGrantStore(),
            random: SequenceRandomBytesGenerator(fallback: randomFallback)
        )
        let grant = try await consumer.pair()
        let tools = try await consumer.listTools(grant: grant)
        XCTAssertEqual(tools.map(\.name), ["clipboard.copy", "clipboard.get", "clipboard.search"])

        let found: ClipboardMCPSearchOutput = try await consumer.call(
            "clipboard.search",
            input: ClipboardMCPSearchInput(query: "Quarterly", kind: .text, limit: 5),
            as: ClipboardMCPSearchOutput.self,
            grant: grant
        )
        XCTAssertEqual(found.items.map(\.id), ["hash-live-text"])
        XCTAssertEqual(found.items.first?.sourceAppName, "Example Editor")

        let content: ClipboardMCPItemContent = try await consumer.call(
            "clipboard.get",
            input: ClipboardMCPGetInput(id: "hash-live-text"),
            as: ClipboardMCPItemContent.self,
            grant: grant
        )
        XCTAssertEqual(content.text, seededText)
        XCTAssertNil(content.textTruncated)

        let pasteboard = NSPasteboard.general
        let savedText = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let savedText { pasteboard.setString(savedText, forType: .string) }
        }
        let receipt: ClipboardMCPCopyReceipt = try await consumer.call(
            "clipboard.copy",
            input: ClipboardMCPCopyInput(id: "hash-live-text"),
            as: ClipboardMCPCopyReceipt.self,
            grant: grant
        )
        XCTAssertTrue(receipt.copied)
        XCTAssertEqual(pasteboard.string(forType: .string), seededText)
        XCTAssertEqual(store.item(withContentHash: "hash-live-text")?.timesCopied, expectedTimesCopied)

        await consumer.close()
    }
}

@MainActor
final class ClipboardMCPToggleLiveTests: XCTestCase {
    // Reproduces the app's real Settings flow: launch with the producer
    // disabled (runs the disabled-branch stop + grant load), then enable.
    func testEnableAfterDisabledStartupReachesRunningWithInMemoryBackends() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-mcp-toggle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(storeDirectory: directory)
        let producer = LocalMCPProducer(
            identity: ProducerIdentity(
                stableID: ClipboardMCPRuntimeFactory.producerID,
                displayName: "Clipboard",
                version: "1.0.0"
            ),
            transport: LocalMCPHTTPProducerTransport(),
            advertiser: DiscoveryCatalog(),
            grantStore: InMemoryProducerGrantStore(),
            approval: RecordingPairingApprover(),
            random: SequenceRandomBytesGenerator(fallback: 40)
        )
        let runtime = LiveClipboardMCPRuntime(
            producer: producer,
            history: HistoryStoreMCPBridge(store: store)
        )
        let controller = ClipboardMCPController(runtime: runtime, defaults: isolatedToggleDefaults())

        controller.startAfterHistoryReady()
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .stopped)

        controller.setEnabled(true)
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .running)

        await controller.shutdown()
        XCTAssertEqual(controller.status, .stopped)
    }

    // Same flow against the production backends (real Bonjour advertiser,
    // real login-keychain grant store) to catch environment-specific hangs.
    func testEnableAfterDisabledStartupReachesRunningWithProductionBackends() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-mcp-toggle-prod-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(storeDirectory: directory)
        let runtime = try ClipboardMCPRuntimeFactory.makeLive(
            history: HistoryStoreMCPBridge(store: store)
        )
        let controller = ClipboardMCPController(runtime: runtime, defaults: isolatedToggleDefaults())

        controller.startAfterHistoryReady()
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .stopped)

        controller.setEnabled(true)
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .running, "issue: \(controller.lastIssueCode ?? "none")")

        await controller.shutdown()
        XCTAssertEqual(controller.status, .stopped)
    }

    private func isolatedToggleDefaults() -> UserDefaults {
        let suite = "ClipboardMCPToggleLiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

@MainActor
final class ClipboardMCPControllerTests: XCTestCase {
    func testDisabledStartIsStoppedAndEnableDisableDrivesRealRuntimeState() async {
        let defaults = isolatedDefaults()
        let runtime = RecordingClipboardMCPRuntime()
        let controller = ClipboardMCPController(runtime: runtime, defaults: defaults)

        XCTAssertFalse(controller.isEnabled)
        controller.startAfterHistoryReady()
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .stopped)

        controller.setEnabled(true)
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .running)
        XCTAssertTrue(defaults.bool(forKey: ClipboardMCPController.enabledDefaultsKey))

        controller.setEnabled(false)
        await controller.waitForTransitions()
        XCTAssertEqual(controller.status, .stopped)
        let events = await runtime.events
        XCTAssertEqual(events, ["stop", "start", "stop"])
    }

    func testControllerListsAndImmediatelyRevokesGrant() async throws {
        let metadata = grantMetadata()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ClipboardMCPController.enabledDefaultsKey)
        let runtime = RecordingClipboardMCPRuntime(grants: [metadata])
        let controller = ClipboardMCPController(runtime: runtime, defaults: defaults)

        controller.startAfterHistoryReady()
        await controller.waitForTransitions()
        let grant = try XCTUnwrap(controller.grants.first)
        XCTAssertEqual(grant.consumerName, "Example Consumer")
        XCTAssertEqual(grant.installationSuffix, "00000042")

        controller.revoke(grantID: grant.id)
        for _ in 0..<100 where controller.grants.first?.revokedAt == nil {
            await Task.yield()
        }
        XCTAssertNotNil(controller.grants.first?.revokedAt)
        XCTAssertTrue(controller.diagnostics.contains("Active grants: 0"))
        XCTAssertTrue(controller.diagnostics.contains("Revoked grants: 1"))
    }

    func testDiagnosticsNeverIncludeRawStartupError() async {
        let secret = "seeded-secret-token-and-path-/Users/private"
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ClipboardMCPController.enabledDefaultsKey)
        let runtime = RecordingClipboardMCPRuntime(startFailure: SeededRuntimeError(value: secret))
        let controller = ClipboardMCPController(runtime: runtime, defaults: defaults)

        controller.startAfterHistoryReady()
        await controller.waitForTransitions()

        XCTAssertEqual(controller.status, .failed)
        XCTAssertTrue(controller.diagnostics.contains("producer_start_failed"))
        XCTAssertFalse(controller.diagnostics.contains(secret))
        XCTAssertFalse(controller.diagnostics.contains("/Users/private"))
    }

    func testShutdownStopsRuntimeWithoutChangingPersistedPreference() async {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ClipboardMCPController.enabledDefaultsKey)
        let runtime = RecordingClipboardMCPRuntime()
        let controller = ClipboardMCPController(runtime: runtime, defaults: defaults)
        controller.startAfterHistoryReady()
        await controller.waitForTransitions()

        await controller.shutdown()

        XCTAssertEqual(controller.status, .stopped)
        XCTAssertTrue(defaults.bool(forKey: ClipboardMCPController.enabledDefaultsKey))
        let events = await runtime.events
        XCTAssertEqual(events, ["start", "stop"])
    }

    func testApprovalMapsClaimCodeAndInstallationSuffixToExplicitPresenter() async throws {
        let presenter = CapturingPairingPresenter(decision: .approve)
        let approver = ClipboardPairingApprover(presenter: presenter)
        let nonce = try PairingNonce(bytes: Array(repeating: 7, count: 32))
        let consumer = ConsumerIdentity(
            stableID: "com.example.consumer",
            displayName: "Example Consumer",
            version: "1.0",
            installationID: "00000000-0000-0000-0000-000000000042"
        )
        let challenge = PairingChallenge(
            requestID: "request",
            consumer: consumer,
            verificationCode: PairingVerificationCode(nonce: nonce),
            expiresAt: Date().addingTimeInterval(60)
        )

        let decision = try await approver.decide(challenge)
        XCTAssertEqual(decision, .approve)
        let prompt = try XCTUnwrap(presenter.prompt)
        XCTAssertEqual(prompt.consumerName, "Example Consumer")
        XCTAssertEqual(prompt.consumerStableID, "com.example.consumer")
        XCTAssertEqual(prompt.installationSuffix, "00000042")
        XCTAssertEqual(prompt.verificationCode.count, 8)
    }

    func testPresentationGateRejectsConcurrentAndStaleCancellation() {
        var gate = ClipboardPairingPresentationGate()
        let active = UUID()
        let stale = UUID()

        XCTAssertTrue(gate.begin(active))
        XCTAssertFalse(gate.begin(stale))
        XCTAssertTrue(gate.acceptsCancellation(for: active))
        XCTAssertFalse(gate.acceptsCancellation(for: stale))
        gate.finish(stale)
        XCTAssertTrue(gate.acceptsCancellation(for: active))
        gate.finish(active)
        XCTAssertNil(gate.activeID)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "ClipboardMCPControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

private struct HistorySearchCall: Equatable, Sendable {
    var query: String
    var kind: ClipboardMCPKindFilter?
    var limit: Int
}

private actor RecordingClipboardHistory: ClipboardHistoryProviding {
    private(set) var searchCalls: [HistorySearchCall] = []
    private(set) var itemIDs: [String] = []
    private(set) var copyIDs: [String] = []

    func search(query: String, kind: ClipboardMCPKindFilter?, limit: Int) async -> [ClipboardMCPItemSummary] {
        searchCalls.append(HistorySearchCall(query: query, kind: kind, limit: limit))
        return []
    }

    func item(id: String) async -> ClipboardMCPItemContent? {
        itemIDs.append(id)
        return nil
    }

    func copyItem(id: String) async -> ClipboardMCPCopyReceipt? {
        copyIDs.append(id)
        return nil
    }
}

private struct SeededRuntimeError: Error, Sendable {
    var value: String
}

private actor RecordingClipboardMCPRuntime: ClipboardMCPRuntimeControlling {
    private(set) var events: [String] = []
    private var storedGrants: [AuthorizationGrantMetadata]
    private let startFailure: SeededRuntimeError?

    init(
        grants: [AuthorizationGrantMetadata] = [],
        startFailure: SeededRuntimeError? = nil
    ) {
        storedGrants = grants
        self.startFailure = startFailure
    }

    func start() async throws {
        events.append("start")
        if let startFailure { throw startFailure }
    }

    func stop() async {
        events.append("stop")
    }

    func grants() async throws -> [AuthorizationGrantMetadata] {
        storedGrants
    }

    func revoke(grantID: String) async throws {
        guard let index = storedGrants.firstIndex(where: { $0.grantID == grantID }) else { return }
        storedGrants[index].revokedAt = Date(timeIntervalSince1970: 99)
    }
}

@MainActor
private final class CapturingPairingPresenter: ClipboardPairingPromptPresenting {
    private let decision: PairingDecision
    private(set) var prompt: ClipboardPairingPrompt?

    init(decision: PairingDecision) {
        self.decision = decision
    }

    func present(_ prompt: ClipboardPairingPrompt) async -> PairingDecision {
        self.prompt = prompt
        return decision
    }
}

private func commandContext() -> CommandContext {
    CommandContext(
        consumer: ConsumerIdentity(
            stableID: "com.example.consumer",
            displayName: "Example Consumer",
            version: "1.0",
            installationID: "00000000-0000-0000-0000-000000000042"
        ),
        grantID: "grant",
        requestID: "request",
        deadline: nil
    )
}

private func grantMetadata() -> AuthorizationGrantMetadata {
    AuthorizationGrantMetadata(
        grantID: "grant-1",
        producerID: ClipboardMCPRuntimeFactory.producerID,
        consumer: ConsumerIdentity(
            stableID: "com.example.consumer",
            displayName: "Example Consumer",
            version: "1.0",
            installationID: "00000000-0000-0000-0000-000000000042"
        ),
        issuedAt: Date(timeIntervalSince1970: 10)
    )
}
