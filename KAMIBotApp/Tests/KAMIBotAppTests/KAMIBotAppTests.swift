import AppKit
import Foundation
import XCTest
@testable import KAMIBotApp

@MainActor
final class KAMIBotAppTests: XCTestCase {
    func testNotchGeometryFramesStayNearTopCenter() {
        guard let screen = NSScreen.main else {
            XCTFail("Expected a main screen")
            return
        }

        let notchFrame = NotchGeometry.notchFrame(on: screen)
        let expanded = NotchGeometry.expandedFrame(on: screen)

        XCTAssertEqual(notchFrame.midX, screen.frame.midX, accuracy: 1.0)
        XCTAssertGreaterThan(notchFrame.maxY, screen.frame.maxY - 1.0)
        XCTAssertLessThan(expanded.maxY, notchFrame.minY)
    }

    func testSettingsStorePersistsRecordingDirectoryPath() {
        let suite = "KAMIBotAppTests.SettingsStore.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Failed to create isolated defaults")
            return
        }
        defaults.removePersistentDomain(forName: suite)

        let firstStore = SettingsStore(defaults: defaults)
        firstStore.recordingsDirectoryPath = "/tmp/kami-recorder-tests"
        firstStore.save(defaults: defaults)

        let secondStore = SettingsStore(defaults: defaults)
        XCTAssertEqual(secondStore.recordingsDirectoryPath, "/tmp/kami-recorder-tests")

        defaults.removePersistentDomain(forName: suite)
    }
}
