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
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.30.0"),
        .package(url: "https://github.com/petrukha-ivan/swift-json-schema.git", from: "2.0.2"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(name: "Smoketest", dependencies: [.product(name: "Cast", package: "Cast")]),
        .executableTarget(
            name: "HelloCast",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "PropertyWrappersTour",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "NestedTypes",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(name: "Classify", dependencies: [.product(name: "Cast", package: "Cast")]),
        .executableTarget(
            name: "GenerationModes",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "Cancellation",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "PrepareWarmup",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "CallerManagedLoading",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ]
        ),
        .executableTarget(
            name: "ValidatorAndExcluding",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .executableTarget(
            name: "ErrorHandling",
            dependencies: [
                .product(name: "Cast", package: "Cast"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Collections", package: "swift-collections")
            ]
        )
    ]
)
