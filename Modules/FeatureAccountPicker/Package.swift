// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureAccountPicker",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FeatureAccountPicker",
            targets: ["FeatureAccountPickerUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "0.59.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.11.1"
        ),
        .package(path: "../Blockchain"),
        .package(path: "../Coincore"),
        .package(path: "../ComposableArchitectureExtensions"),
        .package(path: "../Errors"),
        .package(path: "../Extensions"),
        .package(path: "../Localization"),
        .package(path: "../UIComponents")
    ],
    targets: [
        .target(
            name: "FeatureAccountPickerUI",
            dependencies: [
                .product(name: "BlockchainUI", package: "Blockchain"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "UIComponents", package: "UIComponents"),
                .product(name: "Coincore", package: "Coincore"),
                .product(name: "CombineExtensions", package: "Extensions"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ComposableNavigation", package: "ComposableArchitectureExtensions"),
                .product(name: "ComposableArchitectureExtensions", package: "ComposableArchitectureExtensions"),
                .product(name: "ErrorsUI", package: "Errors")
            ],
            path: "UI"
        ),
        .testTarget(
            name: "FeatureAccountPickerTests",
            dependencies: [
                .target(name: "FeatureAccountPickerUI"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests",
            exclude: ["__Snapshots__"]
        )
    ]
)
