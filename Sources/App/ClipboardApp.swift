import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard History", systemImage: "clipboard") {
            Button("Open Clipboard History") {
                appDelegate.dependencies?.panelController.toggle()
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Button("Clear History…") {
                appDelegate.dependencies?.requestClearAll()
            }
            Divider()
            Button("Quit Clipboard") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsSceneRoot(appDelegate: appDelegate)
        }
    }
}

/// Observes the app delegate so the Settings window rebuilds when the app
/// finishes launching and `dependencies` becomes available. A View with an
/// `@ObservedObject` reliably re-renders on `@Published` changes, whereas the
/// `Settings` scene captures the initial nil snapshot and never refreshes.
private struct SettingsSceneRoot: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        SettingsView(dependencies: appDelegate.dependencies)
    }
}
