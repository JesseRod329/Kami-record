import AudioPipeline
import Foundation
import XCTest
@testable import KAMIBotApp

@MainActor
final class RecorderViewModelTests: XCTestCase {
    func testStartRecordingTransitionsToRecordingState() async {
        let service = MockAudioRecorderService()
        let viewModel = RecorderViewModel(recorderService: service)

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.state, .recording)
        XCTAssertNil(viewModel.errorMessage)
        await viewModel.cancelRecording()
    }

    func testStopRecordingReturnsToIdleAndPersistsLatestArtifact() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/test-capture.m4a")
        let expected = RecordingArtifact(
            fileURL: expectedURL,
            duration: 3.4,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let service = MockAudioRecorderService(stopArtifact: expected)
        let viewModel = RecorderViewModel(recorderService: service)

        await viewModel.startRecording()
        await viewModel.stopRecording()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.latestRecording?.fileURL, expectedURL)
        XCTAssertEqual(viewModel.elapsedTime, 3.4, accuracy: 0.001)
    }

    func testPermissionDeniedSetsErrorState() async {
        let service = MockAudioRecorderService(startError: AudioPipelineError.microphoneDenied)
        let viewModel = RecorderViewModel(recorderService: service)

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.state, .error)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testRefreshLatestRecordingLoadsFromService() async {
        let expected = RecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/latest-capture.m4a"),
            duration: 1.2,
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let service = MockAudioRecorderService(latestArtifact: expected)
        let viewModel = RecorderViewModel(recorderService: service)

        await viewModel.refreshLatestRecording()

        XCTAssertEqual(viewModel.latestRecording?.fileURL, expected.fileURL)
        XCTAssertEqual(viewModel.outputDirectory?.path, "/tmp")
    }

    func testSetOutputDirectoryUpdatesServiceAndState() async {
        let service = MockAudioRecorderService()
        let viewModel = RecorderViewModel(recorderService: service)
        let folder = URL(fileURLWithPath: "/tmp/kami-recordings", isDirectory: true)

        await viewModel.setOutputDirectory(folder)

        XCTAssertEqual(viewModel.outputDirectory?.path, folder.path)
    }
}

actor MockAudioRecorderService: AudioRecorderService {
    private let startError: Error?
    private let stopError: Error?
    private let stopArtifact: RecordingArtifact
    private let setDirectoryError: Error?
    private var latestArtifact: RecordingArtifact?
    private var currentDirectory: URL

    init(
        startError: Error? = nil,
        stopError: Error? = nil,
        setDirectoryError: Error? = nil,
        stopArtifact: RecordingArtifact = RecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/default-capture.m4a"),
            duration: 2.0,
            createdAt: Date(timeIntervalSince1970: 100)
        ),
        latestArtifact: RecordingArtifact? = nil,
        outputDirectory: URL = URL(fileURLWithPath: "/tmp", isDirectory: true)
    ) {
        self.startError = startError
        self.stopError = stopError
        self.setDirectoryError = setDirectoryError
        self.stopArtifact = stopArtifact
        self.latestArtifact = latestArtifact
        self.currentDirectory = outputDirectory
    }

    func startRecording() async throws {
        if let startError {
            throw startError
        }
    }

    func stopRecording() async throws -> RecordingArtifact {
        if let stopError {
            throw stopError
        }
        latestArtifact = stopArtifact
        return stopArtifact
    }

    func cancelRecording() async {}

    func latestRecording() async -> RecordingArtifact? {
        latestArtifact
    }

    func outputDirectory() async -> URL {
        currentDirectory
    }

    func setOutputDirectory(_ url: URL) async throws {
        if let setDirectoryError {
            throw setDirectoryError
        }
        currentDirectory = url
    }
}
