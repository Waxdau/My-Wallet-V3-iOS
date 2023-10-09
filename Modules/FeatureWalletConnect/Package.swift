// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureWalletConnect",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FeatureWalletConnect",
            targets: [
                "FeatureWalletConnectDomain",
                "FeatureWalletConnectUI"
            ]
        ),
        .library(
            name: "FeatureWalletConnectDomain",
            targets: ["FeatureWalletConnectDomain"]
        ),
        .library(
            name: "FeatureWalletConnectUI",
            targets: ["FeatureWalletConnectUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "0.59.0"
        ),
        .package(
            url: "https://github.com/WalletConnect/WalletConnectSwiftV2",
            exact: "1.6.13"
        ),
        .package(path: "../Analytics"),
        .package(path: "../Blockchain"),
        .package(path: "../Coincore"),
        .package(path: "../Localization"),
        .package(path: "../UIComponents"),
        .package(path: "../CryptoAssets"),
        .package(path: "../WalletPayload"),
        .package(path: "../Network"),
        .package(path: "../Metadata"),
        .package(path: "../Tool")
    ],
    targets: [
        .target(
            name: "FeatureWalletConnectDomain",
            dependencies: [
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "Coincore", package: "Coincore"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "EthereumKit", package: "CryptoAssets"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "MetadataKit", package: "Metadata"),
                .product(name: "NetworkKit", package: "Network"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "WalletPayloadKit", package: "WalletPayload"),
                .product(name: "WalletConnectRouter", package: "WalletConnectSwiftV2"),
                .product(name: "Web3Wallet", package: "WalletConnectSwiftV2")
            ]
        ),
        .target(
            name: "FeatureWalletConnectUI",
            dependencies: [
                .target(name: "FeatureWalletConnectDomain"),
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "BlockchainUI", package: "Blockchain"),
                .product(name: "Coincore", package: "Coincore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "UIComponents", package: "UIComponents")
            ]
        ),
        .testTarget(
            name: "FeatureWalletConnectDomainTests",
            dependencies: [
                .target(name: "FeatureWalletConnectDomain"),
                .product(name: "ToolKitMock", package: "Tool")
            ]
        )
    ]
)
