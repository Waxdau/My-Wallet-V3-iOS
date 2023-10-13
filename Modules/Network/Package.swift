// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Network",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "NetworkKit",
            targets: ["NetworkKit"]
        ),
        .library(
            name: "NetworkKitMock",
            targets: ["NetworkKitMock"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.0.0"
        ),
        .package(name: "AnyCoding", path: "../AnyCoding"),
        .package(name: "Analytics", path: "../Analytics"),
        .package(name: "Test", path: "../Test"),
        .package(name: "Tool", path: "../Tool"),
        .package(name: "Errors", path: "../Errors")
    ],
    targets: [
        .target(
            name: "NetworkKit",
            dependencies: [
                .product(name: "AnyCoding", package: "AnyCoding"),
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "NetworkKitMock",
            dependencies: [
                .target(name: "NetworkKit"),
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "TestKit", package: "Test"),
                .product(name: "ToolKit", package: "Tool")
            ]
        ),
        .testTarget(
            name: "NetworkKitTests",
            dependencies: [
                .target(name: "NetworkKit"),
                .product(name: "TestKit", package: "Test")
            ]
        )
    ]
)
