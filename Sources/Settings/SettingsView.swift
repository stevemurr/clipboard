import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies?
    @AppStorage(PrefKey.historyLimit) private var historyLimit = 1000
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle clipboard history:", name: .togglePanel)
            }
            Section {
                Picker("Keep at most:", selection: $historyLimit) {
                    Text("100 items").tag(100)
                    Text("500 items").tag(500)
                    Text("1,000 items").tag(1000)
                    Text("5,000 items").tag(5000)
                    Text("Unlimited").tag(0)
                }
            }
            Section {
                Button("Clear History…", role: .destructive) {
                    confirmingClear = true
                }
                .confirmationDialog(
                    "Clear all clipboard history?",
                    isPresented: $confirmingClear
                ) {
                    Button("Clear History", role: .destructive) {
                        dependencies?.store.clearAll()
                    }
                } message: {
                    Text("This removes every saved entry, including stored images. This cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
        .onChange(of: historyLimit) {
            dependencies?.store.prune()
        }
    }
}
