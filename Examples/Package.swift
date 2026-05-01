// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CastExamples",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.30.0")
    ],
    targets: [
        .executableTarget(name: "Smoketest", dependencies: [.product(name: "Cast", package: "Cast")]),
        .executableTarget(
            name: "HelloCast",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "PropertyWrappersTour",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "NestedTypes",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(name: "Classify", dependencies: [.product(name: "Cast", package: "Cast")]),
        .executableTarget(
            name: "GenerationModes",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "Cancellation",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "PrepareWarmup",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "CallerManagedLoading",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ]
        ),
        .executableTarget(
            name: "CustomModelSource",
            dependencies: [.product(name: "Cast", package: "Cast")],
            path: "Sources/CustomModelSource"
        ),
        .executableTarget(
            name: "ValidatorAndExcluding",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "ErrorHandling",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "ChatTemplates",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "Extract",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "CastBench",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "Streaming",
            dependencies: [.product(name: "Cast", package: "Cast")]
        ),
        .executableTarget(
            name: "SwiftUIDemo",
            dependencies: [.product(name: "Cast", package: "Cast")]
        )
    ]
)
