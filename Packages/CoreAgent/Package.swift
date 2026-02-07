// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoreAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CoreAgent", targets: ["CoreAgent"])
    ],
    dependencies: [],
    targets: [
        .target(name: "CoreAgent"),
        .testTarget(
            name: "CoreAgentTests",
            dependencies: ["CoreAgent"]
        )
    ]
)
