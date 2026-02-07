// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AudioPipeline",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AudioPipeline", targets: ["AudioPipeline"])
    ],
    dependencies: [
        .package(path: "../CoreAgent")
    ],
    targets: [
        .target(name: "AudioPipeline", dependencies: ["CoreAgent"]),
        .testTarget(
            name: "AudioPipelineTests",
            dependencies: ["AudioPipeline"]
        )
    ]
)
