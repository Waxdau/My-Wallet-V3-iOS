// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureAuthentication",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FeatureAuthentication",
            targets: ["FeatureAuthenticationData", "FeatureAuthenticationDomain", "FeatureAuthenticationUI"]
        ),
        .library(
            name: "FeatureAuthenticationData",
            targets: ["FeatureAuthenticationData"]
        ),
        .library(
            name: "FeatureAuthenticationUI",
            targets: ["FeatureAuthenticationUI"]
        ),
        .library(
            name: "FeatureAuthenticationDomain",
            targets: ["FeatureAuthenticationDomain"]
        ),
        .library(
            name: "FeatureAuthenticationMock",
            targets: ["FeatureAuthenticationMock"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.2.0"
        ),
        .package(path: "../Analytics"),
        .package(path: "../Blockchain"),
        .package(path: "../BlockchainNamespace"),
        .package(path: "../ComposableArchitectureExtensions"),
        .package(path: "../Localization"),
        .package(path: "../Network"),
        .package(path: "../Errors"),
        .package(path: "../Test"),
        .package(path: "../Tool"),
        .package(path: "../UIComponents"),
        .package(path: "../WalletPayload"),
        .package(path: "../Money")
    ],
    targets: [
        .target(
            name: "FeatureAuthenticationDomain",
            dependencies: [
                .product(name: "Blockchain", package: "Blockchain"),
                .product(name: "NetworkKit", package: "Network"),
                .product(name: "MoneyKit", package: "Money"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "WalletPayloadKit", package: "WalletPayload")
            ]
        ),
        .target(
            name: "FeatureAuthenticationData",
            dependencies: [
                .target(name: "FeatureAuthenticationDomain"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "NetworkKit", package: "Network"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "WalletPayloadKit", package: "WalletPayload")
            ]
        ),
        .target(
            name: "FeatureAuthenticationUI",
            dependencies: [
                .target(name: "FeatureAuthenticationDomain"),
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace"),
                .product(name: "BlockchainUI", package: "Blockchain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ComposableNavigation", package: "ComposableArchitectureExtensions"),
                .product(name: "ErrorsUI", package: "Errors"),
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "UIComponents", package: "UIComponents")
            ]
        ),
        .target(
            name: "FeatureAuthenticationMock",
            dependencies: [
                .target(name: "FeatureAuthenticationData"),
                .target(name: "FeatureAuthenticationDomain"),
                .product(name: "WalletPayloadKit", package: "WalletPayload"),
                .product(name: "WalletPayloadDataKit", package: "WalletPayload"),
                .product(name: "WalletPayloadKitMock", package: "WalletPayload")
            ]
        ),
        .testTarget(
            name: "FeatureAuthenticationDataTests",
            dependencies: [
                .target(name: "FeatureAuthenticationData"),
                .target(name: "FeatureAuthenticationMock"),
                .product(name: "ToolKitMock", package: "Tool"),
                .product(name: "WalletPayloadKit", package: "WalletPayload"),
                .product(name: "WalletPayloadDataKit", package: "WalletPayload"),
                .product(name: "WalletPayloadKitMock", package: "WalletPayload"),
                .product(name: "TestKit", package: "Test")
            ]
        ),
        .testTarget(
            name: "FeatureAuthenticationUITests",
            dependencies: [
                .target(name: "FeatureAuthenticationData"),
                .target(name: "FeatureAuthenticationMock"),
                .target(name: "FeatureAuthenticationUI"),
                .product(name: "AnalyticsKitMock", package: "Analytics"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "ErrorsUI", package: "Errors"),
                .product(name: "TestKit", package: "Test"),
                .product(name: "ToolKitMock", package: "Tool")
            ]
        )
    ]
)
