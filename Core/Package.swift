// swift-tools-version:5.9
// Plattformunabhängige Logik, damit `swift test` ohne Simulator läuft.
import PackageDescription

let package = Package(
    name: "GameMapCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameMapCore", targets: ["GameMapCore"])
    ],
    targets: [
        .target(name: "GameMapCore", path: "Sources/GameMapCore"),
        .testTarget(name: "GameMapCoreTests", dependencies: ["GameMapCore"], path: "Tests/GameMapCoreTests")
    ]
)
