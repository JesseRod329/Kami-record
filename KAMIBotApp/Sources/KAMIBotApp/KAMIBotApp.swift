import SwiftUI

@main
struct KAMIBotApp: App {
    @State private var settingsStore: SettingsStore
    @State private var viewModel: BMOViewModel
    @State private var recorderViewModel: RecorderViewModel

    init() {
        let settingsStore = SettingsStore()
        let container = AppContainer(
            config: settingsStore.toAgentConfig(),
            recordingDirectory: settingsStore.recordingsDirectoryURL
        )
        _settingsStore = State(initialValue: settingsStore)
        _viewModel = State(
            initialValue: BMOViewModel(
                agent: container.agent,
                audioStartupCoordinator: container.audioStartupCoordinator,
                modelStartupCoordinator: container.modelStartupCoordinator,
                startupChecks: container.startupChecks
            )
        )
        _recorderViewModel = State(
            initialValue: RecorderViewModel(recorderService: container.audioRecorderService)
        )
    }

    var body: some Scene {
        WindowGroup("KAMI RECORD") {
            ContentView(
                viewModel: viewModel,
                recorderViewModel: recorderViewModel,
                settingsStore: settingsStore
            )
                .floatingWindow()
                .frame(minWidth: 420, minHeight: 260)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 300)
    }
}
