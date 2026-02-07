import SwiftUI

@main
struct KAMIBotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settingsStore: appDelegate.settingsStore)
        }
    }
}
