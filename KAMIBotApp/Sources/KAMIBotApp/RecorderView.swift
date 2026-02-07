import AppKit
import SwiftUI
import UIComponents

struct RecorderView: View {
    @Bindable var viewModel: RecorderViewModel
    @Bindable var settingsStore: SettingsStore
    @State private var hasSprungIn = false
    @State private var tapBump = false

    var body: some View {
        VStack(spacing: 12) {
            GlassSurface {
                VStack(spacing: 14) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 86, height: 5)
                        .padding(.top, 2)

                    HStack(spacing: 10) {
                        Label("Simple Recorder", systemImage: "waveform")
                            .font(.headline)

                        Spacer(minLength: 8)

                        Text(viewModel.statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(statusColor.gradient)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        Button {
                            tapBump = true
                            Task {
                                try? await Task.sleep(nanoseconds: 130_000_000)
                                tapBump = false
                            }
                            Task {
                                await viewModel.toggleRecording()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(recordButtonColor.gradient)
                                    .frame(width: 70, height: 70)

                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(recordButtonScale)
                            .shadow(color: recordButtonColor.opacity(0.45), radius: 14, y: 6)
                            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: tapBump)
                            .animation(.linear(duration: 0.15), value: viewModel.audioLevel)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.primaryButtonTitle)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.elapsedLabel)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.95))

                            RecorderLevelMeter(level: viewModel.audioLevel)
                                .frame(width: 210, height: 12)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: 460)
            .scaleEffect(hasSprungIn ? 1 : 0.84, anchor: .top)
            .offset(y: hasSprungIn ? 0 : -26)
            .opacity(hasSprungIn ? 1 : 0.12)

            if let latest = viewModel.latestRecording {
                Text("Last capture: \(latest.fileURL.lastPathComponent) · \(formatted(date: latest.createdAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No captures saved yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if let outputDirectory = viewModel.outputDirectory {
                HStack(spacing: 8) {
                    Text("Save folder:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(outputDirectory.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 4)

                    Button("Choose Folder") {
                        if let selected = chooseFolder() {
                            settingsStore.recordingsDirectoryPath = selected.path
                            settingsStore.save()
                            Task {
                                await viewModel.setOutputDirectory(selected)
                            }
                        }
                    }
                    .font(.caption)

                    Button("Open") {
                        NSWorkspace.shared.activateFileViewerSelecting([outputDirectory])
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 18)
        .background(
            LinearGradient(
                colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task {
            await viewModel.setOutputDirectory(settingsStore.recordingsDirectoryURL)
            await viewModel.refreshLatestRecording()
        }
        .onAppear {
            hasSprungIn = false
            withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.82, blendDuration: 0.1)) {
                hasSprungIn = true
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .idle:
            Color.gray
        case .recording:
            Color.red
        case .saving:
            Color.orange
        case .error:
            Color.red.opacity(0.75)
        }
    }

    private var recordButtonColor: Color {
        viewModel.isRecording ? .red : .pink
    }

    private var recordButtonScale: Double {
        let livePulse = viewModel.isRecording ? (1 + (viewModel.audioLevel * 0.08)) : 1.0
        return tapBump ? max(1.12, livePulse + 0.05) : livePulse
    }

    private func formatted(date: Date) -> String {
        Self.captureDateFormatter.string(from: date)
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.directoryURL = viewModel.outputDirectory ?? settingsStore.recordingsDirectoryURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static let captureDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RecorderLevelMeter: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(level, 0), 1)
            let width = max(6, proxy.size.width * clamped)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.mint, Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
            }
        }
    }
}
