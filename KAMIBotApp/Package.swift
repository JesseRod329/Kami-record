// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KAMIBotApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KAMIBotApp", targets: ["KAMIBotApp"])
    ],
    dependencies: [
        .package(path: "../Packages/AudioPipeline"),
        .package(path: "../Packages/UIComponents")
    ],
    targets: [
        .executableTarget(
            name: "KAMIBotApp",
            dependencies: [
                "AudioPipeline",
                "UIComponents"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KAMIBotAppTests",
            dependencies: ["KAMIBotApp"]
        )
    ]
)
