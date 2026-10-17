// swift-tools-version:5.9
// Plattformunabhängige Logik, damit `swift test` ohne Simulator läuft.
import PackageDescription

let package = Package(
    name: "EzMapsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EzMapsCore", targets: ["EzMapsCore"])
    ],
    targets: [
        .target(name: "EzMapsCore", path: "Sources/EzMapsCore"),
        .testTarget(name: "EzMapsCoreTests", dependencies: ["EzMapsCore"], path: "Tests/EzMapsCoreTests")
    ]
)
