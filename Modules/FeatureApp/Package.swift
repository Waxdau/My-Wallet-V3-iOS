// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "FeatureApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "FeatureApp", targets: ["FeatureAppUI", "FeatureAppDomain"]),
        .library(name: "FeatureAppUI", targets: ["FeatureAppUI"]),
        .library(name: "FeatureAppDomain", targets: ["FeatureAppDomain"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/ReactiveX/RxSwift.git",
            from: "6.6.0"
        ),
        .package(
            url: "https://github.com/dchatzieleftheriou-bc/DIKit.git",
            exact: "1.0.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.2.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.11.1"
        ),
        .package(path: "../Analytics"),
        .package(path: "../BlockchainComponentLibrary"),
        .package(path: "../BlockchainNamespace"),
        .package(path: "../CryptoAssets"),
        .package(path: "../FeatureAccountPicker"),
        .package(path: "../FeatureAddressSearch"),
        .package(path: "../FeatureAnnouncements"),
        .package(path: "../FeatureTopMoversCrypto"),
        .package(path: "../FeatureAppUpgrade"),
        .package(path: "../FeatureAttribution"),
        .package(path: "../FeatureAuthentication"),
        .package(path: "../FeatureCardPayment"),
        .package(path: "../FeatureCoin"),
        .package(path: "../FeatureDashboard"),
        .package(path: "../FeatureDebug"),
        .package(path: "../FeatureDex"),
        .package(path: "../FeatureInterest"),
        .package(path: "../FeatureNFT"),
        .package(path: "../FeatureOnboarding"),
        .package(path: "../FeatureOpenBanking"),
        .package(path: "../FeaturePaymentsIntegration"),
        .package(path: "../FeaturePin"),
        .package(path: "../FeatureProducts"),
        .package(path: "../FeatureCustodialOnboarding"),
        .package(path: "../FeatureQRCodeScanner"),
        .package(path: "../FeatureSettings"),
        .package(path: "../FeatureSuperAppIntro"),
        .package(path: "../FeatureTour"),
        .package(path: "../FeatureTransaction"),
        .package(path: "../FeatureUnifiedActivity"),
        .package(path: "../FeatureWalletConnect"),
        .package(path: "../FeatureWithdrawalLocks"),
        .package(path: "../FeatureReceive"),
        .package(path: "../Localization"),
        .package(path: "../Money"),
        .package(path: "../Observability"),
        .package(path: "../Platform"),
        .package(path: "../RemoteNotifications"),
        .package(path: "../Tool"),
        .package(path: "../UIComponents"),
        .package(path: "../WalletPayload")
    ],
    targets: [
        .target(
            name: "FeatureAppUI",
            dependencies: [
                .target(name: "FeatureAppDomain"),
                .product(name: "AnalyticsKit", package: "Analytics"),
                .product(name: "BitcoinChainKit", package: "CryptoAssets"),
                .product(name: "BlockchainComponentLibrary", package: "BlockchainComponentLibrary"),
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "ERC20Kit", package: "CryptoAssets"),
                .product(name: "FeatureAccountPicker", package: "FeatureAccountPicker"),
                .product(name: "FeatureAddressSearchUI", package: "FeatureAddressSearch"),
                .product(name: "FeatureAnnouncementsDomain", package: "FeatureAnnouncements"),
                .product(name: "FeatureAnnouncementsUI", package: "FeatureAnnouncements"),
                .product(name: "FeatureAppUpgradeDomain", package: "FeatureAppUpgrade"),
                .product(name: "FeatureAppUpgradeUI", package: "FeatureAppUpgrade"),
                .product(name: "FeatureAttributionDomain", package: "FeatureAttribution"),
                .product(name: "FeatureAuthenticationDomain", package: "FeatureAuthentication"),
                .product(name: "FeatureAuthenticationUI", package: "FeatureAuthentication"),
                .product(name: "FeatureCardPaymentDomain", package: "FeatureCardPayment"),
                .product(name: "FeatureWireTransfer", package: "FeaturePaymentsIntegration"),
                .product(name: "FeatureCoinData", package: "FeatureCoin"),
                .product(name: "FeatureCoinDomain", package: "FeatureCoin"),
                .product(name: "FeatureCoinUI", package: "FeatureCoin"),
                .product(name: "FeatureDashboardUI", package: "FeatureDashboard"),
                .product(name: "FeatureDebugUI", package: "FeatureDebug"),
                .product(name: "FeatureDex", package: "FeatureDex"),
                .product(name: "FeatureInterestUI", package: "FeatureInterest"),
                .product(name: "FeatureNFTDomain", package: "FeatureNFT"),
                .product(name: "FeatureNFTUI", package: "FeatureNFT"),
                .product(name: "FeatureOnboardingUI", package: "FeatureOnboarding"),
                .product(name: "FeatureOpenBankingDomain", package: "FeatureOpenBanking"),
                .product(name: "FeatureOpenBankingUI", package: "FeatureOpenBanking"),
                .product(name: "FeaturePin", package: "FeaturePin"),
                .product(name: "FeatureProductsDomain", package: "FeatureProducts"),
                .product(name: "FeatureQRCodeScannerDomain", package: "FeatureQRCodeScanner"),
                .product(name: "FeatureQRCodeScannerUI", package: "FeatureQRCodeScanner"),
                .product(name: "FeatureSettingsDomain", package: "FeatureSettings"),
                .product(name: "FeatureSettingsUI", package: "FeatureSettings"),
                .product(name: "FeatureSuperAppIntroUI", package: "FeatureSuperAppIntro"),
                .product(name: "FeatureTourUI", package: "FeatureTour"),
                .product(name: "FeatureTopMoversCryptoUI", package: "FeatureTopMoversCrypto"),
                .product(name: "FeatureTransactionUI", package: "FeatureTransaction"),
                .product(name: "FeatureWalletConnectUI", package: "FeatureWalletConnect"),
                .product(name: "FeatureWalletConnectDomain", package: "FeatureWalletConnect"),
                .product(name: "FeatureReceiveUI", package: "FeatureReceive"),
                .product(name: "Localization", package: "Localization"),
                .product(name: "MoneyKit", package: "Money"),
                .product(name: "ObservabilityKit", package: "Observability"),
                .product(name: "PlatformKit", package: "Platform"),
                .product(name: "PlatformUIKit", package: "Platform"),
                .product(name: "RemoteNotificationsKit", package: "RemoteNotifications"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "ToolKit", package: "Tool"),
                .product(name: "UIComponents", package: "UIComponents"),
                .product(name: "UnifiedActivityDomain", package: "FeatureUnifiedActivity"),
                .product(name: "WalletPayloadKit", package: "WalletPayload"),
                .product(name: "FeatureCustodialOnboarding", package: "FeatureCustodialOnboarding")
            ]
        ),
        .target(
            name: "FeatureAppDomain",
            dependencies: [
                .product(name: "BlockchainNamespace", package: "BlockchainNamespace"),
                .product(name: "DIKit", package: "DIKit"),
                .product(name: "FeatureAuthenticationDomain", package: "FeatureAuthentication"),
                .product(name: "FeatureProductsDomain", package: "FeatureProducts"),
                .product(name: "FeatureSettingsDomain", package: "FeatureSettings"),
                .product(name: "FeatureWithdrawalLocksData", package: "FeatureWithdrawalLocks"),
                .product(name: "FeatureWithdrawalLocksDomain", package: "FeatureWithdrawalLocks"),
                .product(name: "PlatformKit", package: "Platform"),
                .product(name: "WalletPayloadKit", package: "WalletPayload")
            ]
        ),
        .testTarget(
            name: "FeatureAppUITests",
            dependencies: [
                .target(name: "FeatureAppUI"),
                .product(name: "PlatformKitMock", package: "Platform"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: ["__Snapshots__"]
        )
    ]
)
