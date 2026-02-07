import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KAMI BOT Settings")
                .font(.title3.weight(.semibold))

            Form {
                TextField("Wake word", text: $settingsStore.wakeWord)
                Toggle("Enable vision (v1.1 path)", isOn: $settingsStore.visionEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recordings folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(settingsStore.recordingsDirectoryPath)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Button("Choose Folder") {
                        if let selected = chooseFolder() {
                            settingsStore.recordingsDirectoryPath = selected.path
                        }
                    }
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Enable telemetry", isOn: $settingsStore.telemetryEnabled)
                        .disabled(true)
                    Text("Telemetry is enforced OFF by project policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Save") {
                    settingsStore.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Restart KAMI BOT after changing settings so startup checks and model setup reinitialize.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.directoryURL = settingsStore.recordingsDirectoryURL
        return panel.runModal() == .OK ? panel.url : nil
    }
}
