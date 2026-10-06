// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StandUpCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "StandUpCore", targets: ["StandUpCore"])
    ],
    targets: [
        .target(
            name: "StandUpCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "StandUpCoreTests",
            dependencies: ["StandUpCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
