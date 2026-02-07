import XCTest
@testable import VisionPipeline

private struct MockFrameCapturer: FrameCapturing {
    let payload: Data

    func captureCurrentFrame() async throws -> Data {
        payload
    }
}

final class VisionPipelineTests: XCTestCase {
    func testVisionFeatureFlag() async {
        let disabled = SnapshotVisionService(enabled: false)
        do {
            _ = try await disabled.captureSnapshotDescription()
            XCTFail("Expected disabled error")
        } catch VisionPipelineError.disabled {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let enabled = SnapshotVisionService(enabled: true)
        await enabled.queueSnapshotSummary("A monitor and a cup")
        do {
            let context = try await enabled.captureSnapshotDescription()
            XCTAssertEqual(context.summary, "A monitor and a cup")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOnDemandCaptureUsesFrameCapturerWhenQueueIsEmpty() async {
        let capturer = MockFrameCapturer(payload: Data([0, 1, 2, 3, 4]))
        let service = SnapshotVisionService(enabled: true, frameCapturer: capturer)

        do {
            let context = try await service.captureSnapshotDescription()
            XCTAssertTrue(context.summary.contains("5 bytes"))
        } catch {
            XCTFail("Expected frame capture summary: \(error)")
        }
    }

    func testCaptureUnavailableWithoutQueuedOrFrameSource() async {
        let service = SnapshotVisionService(enabled: true, frameCapturer: nil)
        do {
            _ = try await service.captureSnapshotDescription()
            XCTFail("Expected captureUnavailable")
        } catch VisionPipelineError.captureUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
