// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MagpieCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MagpieCore",
            targets: ["MagpieCore"]
        )
    ],
    targets: [
        .target(
            name: "MagpieCore",
            dependencies: []
        ),
        .testTarget(
            name: "MagpieCoreTests",
            dependencies: ["MagpieCore"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
