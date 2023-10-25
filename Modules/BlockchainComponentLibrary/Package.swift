// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "BlockchainComponentLibrary",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "BlockchainComponentLibrary",
            targets: [
                "BlockchainComponentLibrary"
            ]
        ),
        .library(
            name: "Examples",
            targets: [
                "Examples"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.14.2"
        ),
        .package(
            url: "https://github.com/apple/swift-markdown.git",
            from: "0.2.0"
        ),
        .package(
            url: "https://github.com/airbnb/lottie-ios.git",
            from: "4.3.3"
        ),
        .package(
            url: "https://github.com/kean/Nuke.git",
            from: "11.6.4"
        ),
        .package(path: "../Extensions"),
        .package(path: "../BlockchainNamespace")
    ],
    targets: [
        .target(
            name: "BlockchainComponentLibrary",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "NukeExtensions", package: "Nuke"),
                .product(name: "Extensions", package: "Extensions"),
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace")
            ],
            resources: [
                .process("Resources/Fonts"),
                .copy("Resources/Animation/loader.json"),
                .copy("Resources/Animation/pricechart.json")
            ]
        ),
        .testTarget(
            name: "BlockchainComponentLibraryTests",
            dependencies: [
                .target(name: "BlockchainComponentLibrary"),
                .target(name: "Examples"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "1 - Base/__Snapshots__",
                "2 - Primitives/__Snapshots__",
                "2 - Primitives/Buttons/__Snapshots__",
                "3 - Compositions/__Snapshots__",
                "3 - Compositions/Rows/__Snapshots__",
                "3 - Compositions/SectionHeaders/__Snapshots__",
                "3 - Compositions/Sheets/__Snapshots__",
                "Utilities/__Snapshots__"
            ]
        ),
        .target(
            name: "Examples",
            dependencies: [
                "BlockchainComponentLibrary"
            ]
        )
    ]
)
