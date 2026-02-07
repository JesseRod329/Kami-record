import Foundation
import CryptoKit
import XCTest
import CoreAgent
@testable import ModelRuntime

final class ModelRuntimeTests: XCTestCase {
    func testModelNotFound() async {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kami-model-tests-\(UUID().uuidString)")
        let service = MLXLLMService(modelID: "missing-model", modelStore: tmp)

        do {
            _ = try await service.generateResponse(prompt: "hello", systemPrompt: "sys", context: nil)
            XCTFail("Expected modelNotFound")
        } catch ModelRuntimeError.modelNotFound(let id) {
            XCTAssertEqual(id, "missing-model")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadFailure() async {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kami-download-tests-\(UUID().uuidString)")
        let downloader = ModelDownloader(baseDirectory: tmp)

        let descriptor = ModelDescriptor(
            id: "llama-3.1-8b-4bit",
            url: URL(string: "https://invalid.invalid/not-found.bin")!,
            sha256: String(repeating: "a", count: 64),
            license: "custom"
        )

        do {
            _ = try await downloader.ensureModelAvailable(descriptor)
            XCTFail("Expected downloadFailed")
        } catch ModelRuntimeError.downloadFailed {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidManifestHashRejectedEarly() async {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kami-manifest-tests-\(UUID().uuidString)")
        let downloader = ModelDownloader(baseDirectory: tmp)

        let descriptor = ModelDescriptor(
            id: "llama-3.1-8b-4bit",
            url: URL(string: "https://example.com/model.bin")!,
            sha256: "not-a-valid-digest",
            license: "custom"
        )

        do {
            _ = try await downloader.ensureModelAvailable(descriptor)
            XCTFail("Expected invalidManifest")
        } catch ModelRuntimeError.invalidManifest {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testModelDownloaderWritesVerifiedModelFromLocalURL() async {
        let sourceDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kami-model-source-\(UUID().uuidString)")
        let sourceFile = sourceDir.appendingPathComponent("model.bin")
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kami-model-out-\(UUID().uuidString)")
        let data = Data("hello-model".utf8)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        do {
            try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
            try data.write(to: sourceFile)
        } catch {
            XCTFail("Failed to create local source model: \(error)")
            return
        }

        let descriptor = ModelDescriptor(
            id: "llama-3.1-8b-4bit",
            url: sourceFile,
            sha256: digest,
            license: "test"
        )

        let downloader = ModelDownloader(baseDirectory: outputDir)
        do {
            let destination = try await downloader.ensureModelAvailable(descriptor)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path()))
        } catch {
            XCTFail("Expected local model download to succeed: \(error)")
        }
    }

    func testPersonaPromptBuilderIncludesVisionContext() {
        let prompt = PersonaPromptBuilder.makePrompt(
            userPrompt: "What do you see?",
            visionContext: .init(summary: "A keyboard")
        )

        XCTAssertTrue(prompt.contains("You are BMO"))
        XCTAssertTrue(prompt.contains("Vision context: A keyboard"))
    }
}
