// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureSuperAppIntro",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FeatureSuperAppIntro",
            targets: ["FeatureSuperAppIntroUI"]
        ),
        .library(
            name: "FeatureSuperAppIntroUI",
            targets: ["FeatureSuperAppIntroUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "0.56.0"),
        .package(path: "../Tool"),
        .package(path: "../BlockchainComponentLibrary"),
        .package(path: "../BlockchainNamespace"),
        .package(path: "../Blockchain"),
        .package(path: "../Localization")
    ],
    targets: [
        .target(
            name: "FeatureSuperAppIntroUI",
            dependencies: [
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace"),
                .product(name: "BlockchainUI", package: "Blockchain"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(
                    name: "BlockchainComponentLibrary",
                    package: "BlockchainComponentLibrary"
                )
            ]
        )
    ]
)
