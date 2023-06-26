// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureCustodialOnboarding",
    platforms: [.macOS(.v13), .iOS(.v14)],
    products: [
        .library(
            name: "FeatureCustodialOnboarding",
            targets: ["FeatureCustodialOnboarding"]
        )
    ],
    dependencies: [
        .package(path: "../Blockchain"),
        .package(path: "../FeatureQuickActions"),
    ],
    targets: [
        .target(
            name: "FeatureCustodialOnboarding",
            dependencies: [
                .product(name: "Blockchain", package: "Blockchain"),
                .product(name: "BlockchainUI", package: "Blockchain"),
                .product(name: "FeatureQuickActions", package: "FeatureQuickActions")
            ]
        ),
        .testTarget(
            name: "FeatureCustodialOnboardingTests",
            dependencies: ["FeatureCustodialOnboarding"]
        )
    ]
)
