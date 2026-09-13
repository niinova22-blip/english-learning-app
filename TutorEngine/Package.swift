// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TutorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TutorEngine", targets: ["TutorEngine"])
    ],
    targets: [
        .target(name: "TutorEngine"),
        .testTarget(
            name: "TutorEngineTests",
            dependencies: ["TutorEngine"]
        )
    ]
)
