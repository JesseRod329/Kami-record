// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ModelRuntime",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ModelRuntime", targets: ["ModelRuntime"])
    ],
    dependencies: [
        .package(path: "../CoreAgent")
    ],
    targets: [
        .target(name: "ModelRuntime", dependencies: ["CoreAgent"]),
        .testTarget(
            name: "ModelRuntimeTests",
            dependencies: ["ModelRuntime"]
        )
    ]
)
