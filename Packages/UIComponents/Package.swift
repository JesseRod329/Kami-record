// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UIComponents", targets: ["UIComponents"])
    ],
    dependencies: [
        .package(path: "../CoreAgent")
    ],
    targets: [
        .target(name: "UIComponents", dependencies: ["CoreAgent"]),
        .testTarget(
            name: "UIComponentsTests",
            dependencies: ["UIComponents"]
        )
    ]
)
