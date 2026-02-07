import CoreAgent
import SwiftUI
import UIComponents

struct ContentView: View {
    @Bindable var viewModel: BMOViewModel
    @Bindable var recorderViewModel: RecorderViewModel
    @Bindable var settingsStore: SettingsStore
    @State private var isShowingSettings = false
    @State private var mode: AppMode = .recorder

    var body: some View {
        VStack(spacing: 14) {
            Picker("Mode", selection: $mode) {
                ForEach(AppMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.top, 16)

            if mode == .recorder {
                RecorderView(viewModel: recorderViewModel, settingsStore: settingsStore)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.86, anchor: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                assistantView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
        .background(
            LinearGradient(
                colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(settingsStore: settingsStore)
        }
    }

    private var assistantView: some View {
        VStack(spacing: 14) {
            GlassSurface {
                BMOFaceView(expression: viewModel.expression, state: viewModel.state)
            }

            Text("State: \(viewModel.state.rawValue.capitalized)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(viewModel.transcript.suffix(4).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: 280, alignment: .leading)

            HStack {
                Button("Start") {
                    viewModel.start()
                }
                Button("Stop") {
                    viewModel.stop()
                }
                Button("Settings") {
                    isShowingSettings = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

private enum AppMode: String, CaseIterable, Identifiable {
    case recorder = "Recorder"
    case assistant = "BMO"

    var id: String { rawValue }
}
