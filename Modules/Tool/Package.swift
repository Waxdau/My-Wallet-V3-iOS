// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "ToolKit",
            targets: ["ToolKit"]
        ),
        .library(
            name: "ToolKitMock",
            targets: ["ToolKitMock"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.20.2"),
        .package(url: "https://github.com/groue/GRDBQuery.git", from: "0.7.0"),
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/attaswift/BigInt.git",
            from: "5.3.0"
        ),
        .package(path: "../BlockchainNamespace"),
        .package(path: "../Extensions"),
        .package(path: "../Test"),
        .package(path: "../Errors")
    ],
    targets: [
        .target(
            name: "ToolKit",
            dependencies: [
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "GRDBQuery", package: "GRDBQuery"),
                .product(name: "Extensions", package: "Extensions"),
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace"),
                .product(name: "Errors", package: "Errors")
            ]
        ),
        .target(
            name: "ToolKitMock",
            dependencies: [
                .target(name: "ToolKit")
            ]
        ),
        .testTarget(
            name: "ToolKitTests",
            dependencies: [
                .target(name: "ToolKit"),
                .target(name: "ToolKitMock"),
                .product(name: "TestKit", package: "Test")
            ]
        )
    ]
)
