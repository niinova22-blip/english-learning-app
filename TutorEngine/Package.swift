// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TutorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TutorEngine", targets: ["TutorEngine"])
    ],
    dependencies: [
        // Pinned to the latest stable release tag as of 2026-09-13:
        // https://github.com/ml-explore/mlx-swift-examples/releases/tag/2.29.1
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "2.29.1")
    ],
    targets: [
        .target(
            name: "TutorEngine",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ]
        ),
        .testTarget(
            name: "TutorEngineTests",
            dependencies: ["TutorEngine"]
        )
    ]
)
