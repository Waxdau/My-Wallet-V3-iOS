// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import DIKit
import FeatureAddressSearchDomain
import FeatureAddressSearchUI
import FeatureAuthenticationDomain
import FeatureCoinData
import FeatureCoinDomain
import FeatureKYCDomain
import FeatureKYCUI
import FeatureOnboardingUI
import FeatureOpenBankingUI
import FeatureQRCodeScannerDomain
import FeatureSettingsUI
import FeatureTransactionDomain
import FeatureTransactionUI
import FeatureWalletConnectDomain
import ObservabilityKit
import PlatformKit
import PlatformUIKit
import ToolKit
import UIKit

extension DependencyContainer {

    public static var featureAppUI = module {

        single { BlurVisualEffectHandler() as BlurVisualEffectHandlerAPI }

        single { () -> BackgroundAppHandlerAPI in
            let timer = BackgroundTaskTimer(
                invalidBackgroundTaskIdentifier: BackgroundTaskIdentifier(
                    identifier: UIBackgroundTaskIdentifier.invalid
                )
            )
            return BackgroundAppHandler(backgroundTaskTimer: timer)
        }

        // MARK: Open Banking

        factory { () -> FeatureOpenBankingUI.FiatCurrencyFormatter in
            FiatCurrencyFormatter()
        }

        factory { () -> FeatureOpenBankingUI.CryptoCurrencyFormatter in
            CryptoCurrencyFormatter()
        }

        factory { LaunchOpenBankingFlow() as StartOpenBanking }

        // MARK: QR Code Scanner

        factory { () -> CryptoTargetQRCodeParserAdapter in
            QRCodeScannerAdapter(
                qrCodeScannerRouter: DIKit.resolve(),
                payloadFactory: DIKit.resolve(),
                topMostViewControllerProvider: DIKit.resolve(),
                navigationRouter: DIKit.resolve()
            )
        }

        factory { () -> QRCodeScannerLinkerAPI in
            QRCodeScannerAdapter(
                qrCodeScannerRouter: DIKit.resolve(),
                payloadFactory: DIKit.resolve(),
                topMostViewControllerProvider: DIKit.resolve(),
                navigationRouter: DIKit.resolve()
            )
        }

        factory { () -> CashIdentityVerificationRouterAPI in
            CashIdentityVerificationRouter()
        }

        single {
            DeepLinkCoordinator(
                app: DIKit.resolve(),
                coincore: DIKit.resolve(),
                exchangeProvider: DIKit.resolve(),
                kycRouter: DIKit.resolve(),
                payloadFactory: DIKit.resolve(),
                topMostViewControllerProvider: DIKit.resolve(),
                transactionsRouter: DIKit.resolve(),
                analyticsRecording: DIKit.resolve(),
                walletConnectService: { DIKit.resolve() },
                onboardingRouter: DIKit.resolve()
            )
        }

        factory { () -> FeatureKYCUI.AddressSearchFlowPresenterAPI in
            AddressSearchFlowPresenter(
                addressSearchRouterRouter: DIKit.resolve()
            ) as FeatureKYCUI.AddressSearchFlowPresenterAPI
        }

        factory {
            AddressSearchRouter(
                topMostViewControllerProvider: DIKit.resolve(),
                addressService: DIKit.resolve()
            ) as FeatureAddressSearchDomain.AddressSearchRouterAPI
        }

        factory {
            AddressKYCService() as FeatureAddressSearchDomain.AddressServiceAPI
        }

        single { () -> AssetInformationRepositoryAPI in
            AssetInformationRepository(
                AssetInformationClient(
                    networkAdapter: DIKit.resolve(),
                    requestBuilder: DIKit.resolve()
                )
            )
        }

        factory { UpdateSettingsClient(DIKit.resolve()) as UpdateSettingsClientAPI }

        // MARK: Adapters

        factory { () -> FeatureOnboardingUI.TransactionsRouterAPI in
            TransactionsAdapter(
                router: DIKit.resolve(),
                coincore: DIKit.resolve(),
                app: DIKit.resolve()
            )
        }

        // MARK: Transactions Module

        factory { () -> PaymentMethodsLinkingAdapterAPI in
            PaymentMethodsLinkingAdapter()
        }

        factory { () -> TransactionsAdapterAPI in
            TransactionsAdapter(
                router: DIKit.resolve(),
                coincore: DIKit.resolve(),
                app: DIKit.resolve()
            )
        }

        factory { () -> PlatformUIKit.KYCRouting in
            KYCAdapter()
        }

        factory { () -> FeatureTransactionUI.UserActionServiceAPI in
            TransactionUserActionService(userService: DIKit.resolve())
        }

        factory { () -> FeatureTransactionDomain.TransactionRestrictionsProviderAPI in
            TransactionUserActionService(userService: DIKit.resolve())
        }

        factory { SimpleBuyAnalyticsService() as PlatformKit.SimpleBuyAnalayticsServicing }

        // MARK: Account Picker

        factory { () -> AccountPickerViewControllable in
            let controller = FeatureAccountPickerControllableAdapter(app: DIKit.resolve())
            return controller as AccountPickerViewControllable
        }

        factory { () -> FeatureSettingsUI.PaymentMethodsLinkerAPI in
            PaymentMethodsLinkingAdapter()
        }

        factory { () -> WalletConnectTabSwapping in
            WalletConnectTabSwap(tabSwapping: DIKit.resolve())
        }
    }
}

private final class WalletConnectTabSwap: WalletConnectTabSwapping {
    let tabSwapping: TabSwapping
    init(tabSwapping: TabSwapping) {
        self.tabSwapping = tabSwapping
    }
    func send(from account: BlockchainAccount, target: TransactionTarget) {
        tabSwapping.send(from: account, target: target)
    }
    func sign(from account: BlockchainAccount, target: TransactionTarget) {
        tabSwapping.sign(from: account, target: target)
    }
}
