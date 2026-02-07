// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KAMIBotApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KAMIBotApp", targets: ["KAMIBotApp"])
    ],
    dependencies: [
        .package(path: "../Packages/CoreAgent"),
        .package(path: "../Packages/AudioPipeline"),
        .package(path: "../Packages/ModelRuntime"),
        .package(path: "../Packages/UIComponents"),
        .package(path: "../Packages/VisionPipeline")
    ],
    targets: [
        .executableTarget(
            name: "KAMIBotApp",
            dependencies: [
                "CoreAgent",
                "AudioPipeline",
                "ModelRuntime",
                "UIComponents",
                "VisionPipeline"
            ]
        ),
        .testTarget(
            name: "KAMIBotAppTests",
            dependencies: ["KAMIBotApp"]
        )
    ]
)
