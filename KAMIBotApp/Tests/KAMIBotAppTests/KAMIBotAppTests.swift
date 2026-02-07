import Foundation
import XCTest
import CoreAgent
import ModelRuntime
@testable import KAMIBotApp

@MainActor
final class KAMIBotAppTests: XCTestCase {
    func testContainerBuildsAgent() {
        let container = AppContainer()
        _ = container.agent
        _ = container.audioRecorderService
        _ = container.audioStartupCoordinator
        _ = container.modelStartupCoordinator
    }

    func testFloatingWindowConfigDefaults() {
        let config = FloatingWindowConfig()
        XCTAssertTrue(config.isBorderless)
        XCTAssertTrue(config.isFloating)
        XCTAssertTrue(config.isTransparent)
        XCTAssertTrue(config.placeTopCenter)
    }

    func testStartupValidatorFailsForUnpinnedModelManifest() {
        let config = AgentConfig(telemetryEnabled: false)
        let descriptor = ModelDescriptor(
            id: "llama-3.1-8b-4bit",
            url: URL(string: "https://example.com/model.bin")!,
            sha256: "not-pinned",
            license: "custom"
        )

        let results = StartupValidator.run(config: config, modelDescriptor: descriptor)
        let modelResult = results.first(where: { $0.id == "model-manifest" })
        XCTAssertEqual(modelResult?.status, .fail)
    }

    func testSettingsStoreEnforcesTelemetryPolicy() {
        let settings = SettingsStore()
        settings.telemetryEnabled = true
        XCTAssertFalse(settings.telemetryEnabled)
    }
}
