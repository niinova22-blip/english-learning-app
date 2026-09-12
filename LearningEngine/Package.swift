// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LearningEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LearningEngine", targets: ["LearningEngine"])
    ],
    targets: [
        .target(name: "LearningEngine"),
        .testTarget(name: "LearningEngineTests", dependencies: ["LearningEngine"])
    ]
)
