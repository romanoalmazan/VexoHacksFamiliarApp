// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VexoBand",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "VexoBand", targets: ["VexoBand"])],
    targets: [
        .target(name: "VexoBand", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "VexoBandTests",
            dependencies: ["VexoBand"],
            resources: [.copy("Resources/test-vectors.json")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
