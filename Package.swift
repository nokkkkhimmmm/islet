// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Islet",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Islet", targets: ["Islet"]),
        .library(name: "IsletCore", targets: ["IsletCore"]),
    ],
    targets: [
        // Pure logic: session parsing, models, aggregation. No AppKit, fully testable.
        .target(
            name: "IsletCore",
            path: "Sources/IsletCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The app shell: notch window, SwiftUI views, menu bar item.
        .executableTarget(
            name: "Islet",
            dependencies: ["IsletCore"],
            path: "Sources/Islet",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IsletCoreTests",
            dependencies: ["IsletCore"],
            path: "Tests/IsletCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
