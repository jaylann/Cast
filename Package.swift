// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Cast",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Cast", targets: ["Cast"]),
    ],
    dependencies: [
        // MLX Swift
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.30.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.30.0"),
        // SwiftSyntax for macros
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // Macro implementation (compiler plugin)
        .macro(
            name: "CastMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        // Main library
        .target(
            name: "Cast",
            dependencies: [
                "CastMacros",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ]
        ),
        // Tests
        .testTarget(
            name: "CastTests",
            dependencies: ["Cast"]
        ),
        .testTarget(
            name: "CastMacroTests",
            dependencies: [
                "CastMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
