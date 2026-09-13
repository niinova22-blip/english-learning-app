// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TutorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TutorEngine", targets: ["TutorEngine"])
    ],
    dependencies: [
        // EXPERIMENT (Task 4 follow-up, see task-4-report.md): temporarily
        // depend directly on mlx-swift instead of mlx-swift-examples, to
        // test whether the MLXLinalg Xcode-linking failure is independent
        // of the swift-transformers/Hub dependency graph. Pinned to the
        // same mlx-swift version (0.29.1) that mlx-swift-examples 2.29.1
        // itself resolves to, for a fair comparison.
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.29.1")
    ],
    targets: [
        .target(
            name: "TutorEngine",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift")
            ]
        ),
        .testTarget(
            name: "TutorEngineTests",
            dependencies: ["TutorEngine"]
        )
    ]
)
