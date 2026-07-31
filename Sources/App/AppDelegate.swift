import AppKit
import KeyboardShortcuts

@MainActor
final class AppDependencies {
    let store: HistoryStore
    let viewModel: AppViewModel
    let monitor: ClipboardMonitor
    let quickLook: QuickLookController
    let panelController: PanelController
    let mcpController: ClipboardMCPController

    static var isUITest: Bool {
        CommandLine.arguments.contains("--uitest")
    }

    static var isUnitTest: Bool {
        !isUITest && (
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                || NSClassFromString("XCTestCase") != nil
        )
    }

    init() throws {
        // UI tests use a throwaway store so they never touch real history.
        let directory: URL = if Self.isUITest {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("clipboard-uitest-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        } else {
            FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Clipboard", isDirectory: true)
        }

        store = try HistoryStore(storeDirectory: directory)
        viewModel = AppViewModel(store: store)
        quickLook = QuickLookController(imageStore: store.imageStore)
        panelController = PanelController(viewModel: viewModel, store: store, quickLook: quickLook)
        monitor = ClipboardMonitor { [store] content, source in
            store.ingest(content, source: source)
        }

        let mcpRuntime = try ClipboardMCPRuntimeFactory.makeLive(
            history: HistoryStoreMCPBridge(store: store)
        )
        if Self.isUITest {
            // Isolated defaults so UI test runs never start the producer or
            // touch the user's real enable preference.
            let defaults = UserDefaults(
                suiteName: "com.stevemurr.clipboard.uitests.localmcp.\(ProcessInfo.processInfo.processIdentifier)"
            )!
            defaults.set(false, forKey: ClipboardMCPController.enabledDefaultsKey)
            mcpController = ClipboardMCPController(runtime: mcpRuntime, defaults: defaults)
        } else {
            mcpController = ClipboardMCPController(runtime: mcpRuntime)
        }

        store.onChange = { [weak viewModel] in viewModel?.refilter() }
        store.onSelfWrite = { [weak monitor] in monitor?.markSelfWrite() }
    }

    func start() {
        store.prune()
        store.sweepOrphanImages()
        quickLook.purgeTempFiles()
        monitor.start()
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak panelController] in
            panelController?.toggle()
        }
        mcpController.startAfterHistoryReady()
        if Self.isUITest {
            panelController.show()
        }
    }

    func stop() async {
        await mcpController.shutdown()
    }

    func requestClearAll() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This removes every saved entry, including stored images. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // Published so the Settings scene re-renders once startup finishes. It is
    // set in applicationDidFinishLaunching, which runs after SwiftUI first
    // builds the scenes; without this, the Settings window keeps the nil
    // snapshot it was built with and the Local MCP section stays disabled.
    @MainActor @Published private(set) var dependencies: AppDependencies?
    @MainActor private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppDependencies.isUnitTest else { return }
        UserDefaults.standard.register(defaults: [PrefKey.historyLimit: 1000])
        do {
            let dependencies = try AppDependencies()
            self.dependencies = dependencies
            dependencies.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Clipboard failed to start"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    // The MCP listener shuts down asynchronously before the process exits so
    // no in-flight consumer request outlives the app.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let dependencies else { return .terminateNow }
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true
        Task { @MainActor in
            await dependencies.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.quickLook.purgeTempFiles()
    }
}
