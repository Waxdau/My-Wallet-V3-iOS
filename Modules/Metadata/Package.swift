// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Metadata",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "MetadataKit",
            targets: ["MetadataKit"]
        ),
        .library(
            name: "MetadataDataKit",
            targets: ["MetadataDataKit"]
        ),
        .library(
            name: "MetadataKitMock",
            targets: ["MetadataKitMock"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/combine-schedulers",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift.git",
            from: "1.8.0"
        ),
        .package(
            url: "https://github.com/paulo-bc/MetadataHDWalletKit",
            exact: "1.0.1"
        ),
        .package(path: "../Network"),
        .package(path: "../Errors"),
        .package(path: "../Test"),
        .package(path: "../Tool")
    ],
    targets: [
        .target(
            name: "_MetadataHDWalletKit",
            dependencies: [.product(name: "MetadataHDWalletKit", package: "MetadataHDWalletKit")],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
        .target(
            name: "MetadataKit",
            dependencies: [
                .target(name: "_MetadataHDWalletKit"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "Errors", package: "Errors")
            ]
        ),
        .testTarget(
            name: "MetadataKitTests",
            dependencies: [
                "MetadataKit",
                "MetadataDataKit",
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "TestKit", package: "Test"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "Errors", package: "Errors")
            ],
            resources: [
                .copy("Fixtures/Entries/Ethereum/ethereum_entry.json"),
                .copy("Fixtures/Entries/Ethereum/ethereum_entry_response.json"),
                .copy("Fixtures/Entries/WalletCredentials/wallet_credentials_entry_response.json"),
                .copy("Fixtures/MetadataResponse/fetch_magic_metadata_response_12TMDMri1VSjbBw8WJvHmFpvpxzTJe7EhU.json"),
                .copy("Fixtures/MetadataResponse/fetch_magic_metadata_response_129GLwNB2EbNRrGMuNSRh9PM83xU2Mpn81.json"),
                .copy("Fixtures/MetadataResponse/root_metadata_response.json"),
                .copy("Fixtures/MetadataResponse/erroneous_root_metadata_response.json")
            ]
        ),
        .target(
            name: "MetadataDataKit",
            dependencies: [
                "MetadataKit",
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "NetworkKit", package: "Network")
            ]
        ),
        .target(
            name: "MetadataKitMock",
            dependencies: [
                "MetadataKit"
            ]
        )
    ]
)
