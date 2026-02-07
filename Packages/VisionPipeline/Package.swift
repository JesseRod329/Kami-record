// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VisionPipeline",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VisionPipeline", targets: ["VisionPipeline"])
    ],
    dependencies: [
        .package(path: "../CoreAgent")
    ],
    targets: [
        .target(name: "VisionPipeline", dependencies: ["CoreAgent"]),
        .testTarget(
            name: "VisionPipelineTests",
            dependencies: ["VisionPipeline"]
        )
    ]
)
