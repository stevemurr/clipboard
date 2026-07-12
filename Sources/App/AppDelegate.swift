import AppKit
import KeyboardShortcuts

@MainActor
final class AppDependencies {
    let store: HistoryStore
    let viewModel: AppViewModel
    let monitor: ClipboardMonitor
    let quickLook: QuickLookController
    let panelController: PanelController

    static var isUITest: Bool {
        CommandLine.arguments.contains("--uitest")
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
        if Self.isUITest {
            panelController.show()
        }
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
    private(set) var dependencies: AppDependencies?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.quickLook.purgeTempFiles()
    }
}
