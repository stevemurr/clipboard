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
            SettingsView(dependencies: appDelegate.dependencies)
        }
    }
}
