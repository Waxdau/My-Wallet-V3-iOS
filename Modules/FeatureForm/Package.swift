// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureForm",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "FeatureForm", targets: ["FeatureFormDomain", "FeatureFormUI"]),
        .library(name: "FeatureFormDomain", targets: ["FeatureFormDomain"]),
        .library(name: "FeatureFormUI", targets: ["FeatureFormUI"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.2.0"
        ),
        .package(path: "../Localization"),
        .package(path: "../BlockchainComponentLibrary"),
        .package(path: "../Extensions")
    ],
    targets: [
        .target(
            name: "FeatureFormDomain",
            dependencies: [
                .product(name: "Extensions", package: "Extensions")
            ]
        ),
        .target(
            name: "FeatureFormUI",
            dependencies: [
                .product(name: "BlockchainComponentLibrary", package: "BlockchainComponentLibrary"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Localization", package: "Localization"),
                .target(name: "FeatureFormDomain")
            ]
        ),
        .testTarget(name: "FeatureFormDomainTests", dependencies: ["FeatureFormDomain"])
    ]
)
