import CoreAgent
import Foundation

public enum VisionPipelineError: Error, Equatable {
    case disabled
    case captureUnavailable
    case captureFailed(String)
}

public protocol FrameCapturing: Sendable {
    func captureCurrentFrame() async throws -> Data
}

public actor SnapshotVisionService: VisionService {
    private let enabled: Bool
    private let frameCapturer: FrameCapturing?
    private var queuedSnapshot: VisionContext?

    public init(enabled: Bool = false, frameCapturer: FrameCapturing? = nil) {
        self.enabled = enabled
        self.frameCapturer = frameCapturer
    }

    public func queueSnapshotSummary(_ summary: String) {
        queuedSnapshot = VisionContext(summary: summary)
    }

    public func captureSnapshotDescription() async throws -> VisionContext {
        guard enabled else {
            throw VisionPipelineError.disabled
        }
        if let queuedSnapshot {
            self.queuedSnapshot = nil
            return queuedSnapshot
        }

        guard let frameCapturer else {
            throw VisionPipelineError.captureUnavailable
        }

        do {
            let frameData = try await frameCapturer.captureCurrentFrame()
            return VisionContext(summary: "Captured on-demand frame (\(frameData.count) bytes).")
        } catch {
            throw VisionPipelineError.captureFailed(error.localizedDescription)
        }
    }
}
