import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies?
    @AppStorage(PrefKey.historyLimit) private var historyLimit = 1000
    @State private var confirmingClear = false

    private var mcpController: ClipboardMCPController? { dependencies?.mcpController }

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

            Section("Local MCP") {
                Toggle(
                    "Allow approved local apps to access clipboard history",
                    isOn: Binding(
                        get: { mcpController?.isEnabled ?? false },
                        set: { mcpController?.setEnabled($0) }
                    )
                )
                .disabled(mcpController == nil)
                .accessibilityIdentifier("local-mcp-enabled")

                LabeledContent(
                    "Status",
                    value: mcpController?.status.label ?? "Starting…"
                )
                .accessibilityIdentifier("local-mcp-status")

                Text("Discovery is not trust. Every consumer must be approved with a matching verification code. Access is limited to this Mac and exposes your clipboard history, which may contain sensitive text.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("local-mcp-trust-copy")
            }

            Section("Authorized Local Apps") {
                if let grants = mcpController?.grants, !grants.isEmpty {
                    ForEach(grants) { grant in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(grant.consumerName)
                                        .fontWeight(.medium)
                                    Text(grant.consumerStableID)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Text("Installation …\(grant.installationSuffix) · approved \(grant.issuedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if grant.revokedAt != nil {
                                    Text("Revoked")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button("Revoke") {
                                        mcpController?.revoke(grantID: grant.id)
                                    }
                                    .disabled(mcpController?.revokingGrantIDs.contains(grant.id) == true)
                                }
                            }
                            if grant.revokedAt != nil {
                                Text("The consumer must pair again before it can access history.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                } else {
                    Text("No apps have been approved. Pairing always requires an explicit Allow decision in Clipboard.")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Access List") {
                    mcpController?.refreshGrants()
                }
                .disabled(mcpController == nil)
            }

            Section("Redacted Diagnostics") {
                Text(mcpController?.diagnostics ?? "Local MCP is starting.")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Button("Copy Redacted Diagnostics") {
                    copyDiagnostics()
                }
                .disabled(mcpController == nil)
                .accessibilityIdentifier("local-mcp-copy-diagnostics")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .frame(minHeight: 620)
        .onChange(of: historyLimit) {
            dependencies?.store.prune()
        }
    }

    private func copyDiagnostics() {
        guard let diagnostics = mcpController?.diagnostics else { return }
        ClipboardPasteboardWriter.writeString(diagnostics)
    }
}
