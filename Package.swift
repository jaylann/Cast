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
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.30.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.30.0"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", from: "1.1.0"),
        .package(url: "https://github.com/petrukha-ivan/swift-json-schema.git", from: "2.0.2"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    ],
    targets: [
        .target(
            name: "CMLXStructured",
            exclude: [
                "xgrammar/web",
                "xgrammar/tests",
                "xgrammar/3rdparty/cpptrace",
                "xgrammar/3rdparty/googletest",
                "xgrammar/3rdparty/dlpack/contrib",
                "xgrammar/3rdparty/dlpack/apps",
                "xgrammar/3rdparty/dlpack/cmake",
                "xgrammar/3rdparty/dlpack/docs",
                "xgrammar/3rdparty/dlpack/tests",
                "xgrammar/3rdparty/picojson",
                "xgrammar/cpp/nanobind",
            ],
            cSettings: [
                .headerSearchPath("xgrammar/include"),
                .headerSearchPath("xgrammar/3rdparty/dlpack/include"),
                .headerSearchPath("xgrammar/3rdparty/picojson"),
            ],
            cxxSettings: [
                .headerSearchPath("xgrammar/include"),
                .headerSearchPath("xgrammar/3rdparty/dlpack/include"),
                .headerSearchPath("xgrammar/3rdparty/picojson"),
            ]
        ),
        .target(
            name: "MLXStructured",
            dependencies: [
                .target(name: "CMLXStructured"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
            ]
        ),
        .macro(
            name: "CastMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Cast",
            dependencies: [
                "CastMacros",
                "MLXStructured",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
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
        .testTarget(
            name: "MLXStructuredTests",
            dependencies: [
                "MLXStructured",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
            ]
        ),
    ],
    cxxLanguageStandard: .gnucxx17
)
