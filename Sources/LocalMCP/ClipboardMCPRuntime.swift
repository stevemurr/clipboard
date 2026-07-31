import AppKit
import Foundation
import LocalMCPContracts
import LocalMCPDiscoveryBonjour
import LocalMCPProducer
import Observation

struct ClipboardPairingPrompt: Equatable, Sendable {
    var consumerName: String
    var consumerStableID: String
    var installationSuffix: String
    var verificationCode: String
    var expiresAt: Date
}

@MainActor
protocol ClipboardPairingPromptPresenting: Sendable {
    func present(_ prompt: ClipboardPairingPrompt) async -> PairingDecision
}

struct ClipboardPairingPresentationGate: Sendable {
    private(set) var activeID: UUID?

    mutating func begin(_ id: UUID) -> Bool {
        guard activeID == nil else { return false }
        activeID = id
        return true
    }

    func acceptsCancellation(for id: UUID) -> Bool {
        activeID == id
    }

    mutating func finish(_ id: UUID) {
        if activeID == id { activeID = nil }
    }
}

@MainActor
final class AppKitClipboardPairingPromptPresenter: ClipboardPairingPromptPresenting {
    private var gate = ClipboardPairingPresentationGate()
    private weak var activeWindow: NSWindow?

    func present(_ prompt: ClipboardPairingPrompt) async -> PairingDecision {
        guard Date() < prompt.expiresAt else { return .deny }
        let presentationID = UUID()
        guard gate.begin(presentationID) else { return .deny }
        defer {
            gate.finish(presentationID)
            activeWindow = nil
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow local access to clipboard history?"
        alert.informativeText = """
            \(prompt.consumerName) claims the identity \(prompt.consumerStableID).
            Installation …\(prompt.installationSuffix)
            Verification code: \(prompt.verificationCode)

            Discovery is not proof of identity. Allow only if this code matches the consumer. Access stays local to this Mac, exposes your clipboard history (which may contain sensitive text), and can be revoked immediately in Clipboard Settings.
            """
        // Deny is deliberately the default button: pairing never defaults to allow.
        alert.addButton(withTitle: "Deny")
        alert.addButton(withTitle: "Allow")

        NSApp.activate(ignoringOtherApps: true)
        activeWindow = alert.window
        let remaining = max(prompt.expiresAt.timeIntervalSinceNow, 0)
        let expiryTimer = Timer.scheduledTimer(
            withTimeInterval: remaining,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.abortPresentation(presentationID)
            }
        }
        defer { expiryTimer.invalidate() }

        let response = await withTaskCancellationHandler {
            alert.runModal()
        } onCancel: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.abortPresentation(presentationID)
                }
            }
        }
        guard !Task.isCancelled, Date() < prompt.expiresAt else { return .deny }
        return response == .alertSecondButtonReturn ? .approve : .deny
    }

    private func abortPresentation(_ id: UUID) {
        guard gate.acceptsCancellation(for: id),
              let activeWindow,
              NSApp.modalWindow === activeWindow
        else { return }
        NSApp.abortModal()
    }
}

struct ClipboardPairingApprover: PairingApproving {
    let presenter: any ClipboardPairingPromptPresenting

    func decide(_ challenge: PairingChallenge) async throws -> PairingDecision {
        try Task.checkCancellation()
        let code = challenge.verificationCode.withUnsafeDisplayValue { $0 }
        let prompt = ClipboardPairingPrompt(
            consumerName: challenge.consumer.displayName,
            consumerStableID: challenge.consumer.stableID,
            installationSuffix: String(challenge.consumer.installationID.suffix(8)),
            verificationCode: code,
            expiresAt: challenge.expiresAt
        )
        let decision = await presenter.present(prompt)
        try Task.checkCancellation()
        return decision
    }
}

protocol ClipboardMCPRuntimeControlling: Sendable {
    func start() async throws
    func stop() async
    func grants() async throws -> [AuthorizationGrantMetadata]
    func revoke(grantID: String) async throws
}

actor LiveClipboardMCPRuntime: ClipboardMCPRuntimeControlling {
    private let producer: LocalMCPProducer
    private let history: any ClipboardHistoryProviding
    private var commandsRegistered = false

    init(producer: LocalMCPProducer, history: any ClipboardHistoryProviding) {
        self.producer = producer
        self.history = history
    }

    func start() async throws {
        if !commandsRegistered {
            try await producer.registerClipboardCommands(history: history)
            commandsRegistered = true
        }
        try await producer.start()
    }

    func stop() async {
        await producer.stop()
    }

    func grants() async throws -> [AuthorizationGrantMetadata] {
        try await producer.grantRecords().map(\.metadata)
    }

    func revoke(grantID: String) async throws {
        try await producer.revokeGrant(grantID)
    }
}

enum ClipboardMCPRuntimeFactory {
    static let producerID = "com.stevemurr.clipboard"
    static let keychainService = "com.stevemurr.clipboard.localmcp.producer-grants.v1"

    @MainActor
    static func makeLive(history: any ClipboardHistoryProviding) throws -> any ClipboardMCPRuntimeControlling {
        let version = (Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String) ?? "1.0.0"
        // Grants live in the data-protection keychain, scoped by the
        // team-derived keychain-access-group entitlement, so they survive
        // rebuilds. The legacy login keychain fails SecItem calls here
        // (surfaced as grant_list_failed / credential_store_failed) because
        // its per-item ACLs bind to the binary's code hash — file-search hit
        // the same failure and moved to team signing + data protection.
        let grantStore = try KeychainProducerGrantStore(
            configuration: .init(service: keychainService, useDataProtectionKeychain: true)
        )
        let approval = ClipboardPairingApprover(
            presenter: AppKitClipboardPairingPromptPresenter()
        )
        let producer = LocalMCPProducer(
            identity: ProducerIdentity(
                stableID: producerID,
                displayName: "Clipboard",
                version: version
            ),
            configuration: .localOnly(),
            transport: LocalMCPHTTPProducerTransport(),
            advertiser: BonjourLocalMCPDiscovery(),
            grantStore: grantStore,
            approval: approval
        )
        return LiveClipboardMCPRuntime(producer: producer, history: history)
    }
}

enum ClipboardMCPStatus: Equatable, Sendable {
    case stopped
    case starting
    case running
    case stopping
    case failed

    var label: String {
        switch self {
        case .stopped: "Stopped"
        case .starting: "Starting…"
        case .running: "Running on this Mac"
        case .stopping: "Stopping…"
        case .failed: "Unavailable"
        }
    }
}

struct ClipboardGrantViewState: Identifiable, Equatable, Sendable {
    var id: String
    var consumerName: String
    var consumerStableID: String
    var installationSuffix: String
    var issuedAt: Date
    var revokedAt: Date?

    init(metadata: AuthorizationGrantMetadata) {
        id = metadata.grantID
        consumerName = metadata.consumer.displayName
        consumerStableID = metadata.consumer.stableID
        installationSuffix = String(metadata.consumer.installationID.suffix(8))
        issuedAt = metadata.issuedAt
        revokedAt = metadata.revokedAt
    }
}

@MainActor
@Observable
final class ClipboardMCPController {
    static let enabledDefaultsKey = "localMCPProducerEnabled"

    private let runtime: any ClipboardMCPRuntimeControlling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var transitionTask: Task<Void, Never>?
    @ObservationIgnored private var transitionGeneration: UInt64 = 0
    @ObservationIgnored private var historyDidStart = false
    @ObservationIgnored private var isShuttingDown = false

    private(set) var isEnabled: Bool
    private(set) var status: ClipboardMCPStatus = .stopped
    private(set) var grants: [ClipboardGrantViewState] = []
    private(set) var revokingGrantIDs: Set<String> = []
    private(set) var lastIssueCode: String?

    init(
        runtime: any ClipboardMCPRuntimeControlling,
        defaults: UserDefaults = .standard
    ) {
        self.runtime = runtime
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
    }

    func startAfterHistoryReady() {
        guard !historyDidStart, !isShuttingDown else { return }
        historyDidStart = true
        scheduleTransition()
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled, !isShuttingDown else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledDefaultsKey)
        scheduleTransition()
    }

    func refreshGrants() {
        Task { [weak self] in await self?.loadGrants() }
    }

    func revoke(grantID: String) {
        guard grants.contains(where: { $0.id == grantID && $0.revokedAt == nil }),
              !revokingGrantIDs.contains(grantID)
        else { return }
        revokingGrantIDs.insert(grantID)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await runtime.revoke(grantID: grantID)
            } catch {
                lastIssueCode = "grant_revoke_failed"
            }
            revokingGrantIDs.remove(grantID)
            await loadGrants()
        }
    }

    func shutdown() async {
        guard !isShuttingDown else {
            await transitionTask?.value
            return
        }
        isShuttingDown = true
        transitionGeneration &+= 1
        transitionTask?.cancel()
        status = .stopping
        await runtime.stop()
        status = .stopped
    }

    func waitForTransitions() async {
        await transitionTask?.value
    }

    var diagnostics: String {
        let activeCount = grants.lazy.filter { $0.revokedAt == nil }.count
        let revokedCount = grants.count - activeCount
        return [
            "Producer: \(ClipboardMCPRuntimeFactory.producerID)",
            "State: \(status.label)",
            "Listener: IPv4 loopback only",
            "Discovery: LocalOnly",
            "Active grants: \(activeCount)",
            "Revoked grants: \(revokedCount)",
            "Last issue: \(lastIssueCode ?? "none")",
            "Sensitive payload logging: disabled",
        ].joined(separator: "\n")
    }

    private func scheduleTransition() {
        transitionGeneration &+= 1
        let generation = transitionGeneration
        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            guard let self else { return }
            await applyDesiredState(generation: generation)
        }
    }

    private func applyDesiredState(generation: UInt64) async {
        guard historyDidStart, !isShuttingDown else { return }
        if isEnabled {
            status = .starting
            do {
                try await runtime.start()
                guard generation == transitionGeneration, isEnabled, !isShuttingDown else {
                    await runtime.stop()
                    return
                }
                status = .running
                lastIssueCode = nil
            } catch is CancellationError {
                guard generation == transitionGeneration else { return }
                status = .stopped
            } catch let error as LocalMCPError {
                guard generation == transitionGeneration else { return }
                status = .failed
                lastIssueCode = Self.issueCode(for: error)
            } catch {
                guard generation == transitionGeneration else { return }
                status = .failed
                lastIssueCode = "producer_start_failed"
            }
        } else {
            status = status == .stopped ? .stopped : .stopping
            await runtime.stop()
            guard generation == transitionGeneration else { return }
            status = .stopped
        }
        await loadGrants()
    }

    private func loadGrants() async {
        do {
            let metadata = try await runtime.grants()
            grants = metadata.map(ClipboardGrantViewState.init(metadata:)).sorted {
                if $0.issuedAt == $1.issuedAt { return $0.id < $1.id }
                return $0.issuedAt > $1.issuedAt
            }
        } catch {
            lastIssueCode = "grant_list_failed"
        }
    }

    private static func issueCode(for error: LocalMCPError) -> String {
        switch error {
        case .bindFailed: "listener_start_failed"
        case .advertisementFailed: "discovery_start_failed"
        case .credentialStoreFailed: "credential_store_failed"
        case .cancelled: "cancelled"
        default: "producer_start_failed"
        }
    }
}
