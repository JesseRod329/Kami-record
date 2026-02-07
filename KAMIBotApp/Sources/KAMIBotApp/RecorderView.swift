import SwiftUI
import UIComponents

struct RecorderView: View {
    @Bindable var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 12) {
            GlassSurface {
                VStack(spacing: 14) {
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
                            .scaleEffect(viewModel.isRecording ? 1.08 : 1.0)
                            .shadow(color: recordButtonColor.opacity(0.45), radius: 14, y: 6)
                            .animation(
                                viewModel.isRecording
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .easeOut(duration: 0.2),
                                value: viewModel.isRecording
                            )
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
            await viewModel.refreshLatestRecording()
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

    private func formatted(date: Date) -> String {
        Self.captureDateFormatter.string(from: date)
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
