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
}
