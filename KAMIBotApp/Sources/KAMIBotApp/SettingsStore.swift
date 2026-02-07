import AudioPipeline
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let recordingsDirectoryPath = "settings.recordingsDirectoryPath"
    }

    var recordingsDirectoryPath: String

    init(defaults: UserDefaults = .standard) {
        let defaultRecordingsDirectory = LocalAudioRecorderService.defaultOutputDirectory().path
        self.recordingsDirectoryPath = defaults.string(forKey: Keys.recordingsDirectoryPath) ?? defaultRecordingsDirectory
    }

    var recordingsDirectoryURL: URL {
        URL(fileURLWithPath: recordingsDirectoryPath, isDirectory: true)
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(recordingsDirectoryPath, forKey: Keys.recordingsDirectoryPath)
    }
}
