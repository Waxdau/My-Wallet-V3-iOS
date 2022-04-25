// Copyright © Blockchain Luxembourg S.A. All rights reserved.
// swiftlint:disable file_length

import AnalyticsKit
import BitcoinCashKit
import BitcoinChainKit
import BitcoinKit
import BlockchainNamespace
import Combine
import DIKit
import ERC20Kit
import EthereumKit
import FeatureAppDomain
import FeatureAppUI
import FeatureAuthenticationData
import FeatureAuthenticationDomain
import FeatureCoinData
import FeatureCoinDomain
import FeatureCryptoDomainData
import FeatureCryptoDomainDomain
import FeatureDashboardUI
import FeatureDebugUI
import FeatureKYCDomain
import FeatureKYCUI
import FeatureNFTData
import FeatureNFTDomain
import FeatureOnboardingUI
import FeatureOpenBankingData
import FeatureOpenBankingDomain
import FeatureOpenBankingUI
import FeatureProductsData
import FeatureProductsDomain
import FeatureSettingsDomain
import FeatureSettingsUI
import FeatureTransactionDomain
import FeatureTransactionUI
import FeatureWalletConnectData
import FirebaseMessaging
import FirebaseRemoteConfig
import MoneyKit
import NetworkKit
import PlatformKit
import PlatformUIKit
import RemoteNotificationsKit
import RxToolKit
import StellarKit
import ToolKit
import WalletPayloadKit
import FeatureNotificationPreferencesData
import FeatureNotificationPreferencesDomain

// MARK: - Settings Dependencies

extension ExchangeCoordinator: FeatureSettingsUI.ExchangeCoordinating {}

extension UIApplication: PlatformKit.AppStoreOpening {}

extension Wallet: WalletRecoveryVerifing {}

// MARK: - Dashboard Dependencies

extension AnalyticsUserPropertyInteractor: FeatureDashboardUI.AnalyticsUserPropertyInteracting {}

extension AnnouncementPresenter: FeatureDashboardUI.AnnouncementPresenting {}

extension FeatureSettingsUI.BackupFundsRouter: FeatureDashboardUI.BackupRouterAPI {}

// MARK: - AnalyticsKit Dependencies

extension BlockchainSettings.App: AnalyticsKit.GuidRepositoryAPI {}

// MARK: - Blockchain Module

extension DependencyContainer {
    
    // swiftlint:disable closure_body_length
    static var blockchain = module {
        
        factory { NavigationRouter() as NavigationRouterAPI }
        
        single { OnboardingSettings() }
        
        factory { () -> OnboardingSettingsAPI in
            let settings: OnboardingSettings = DIKit.resolve()
            return settings as OnboardingSettingsAPI
        }
        
        factory { AirdropRouter() as AirdropRouterAPI }
        
        factory { AirdropCenterClient() as AirdropCenterClientAPI }
        
        factory { AirdropCenterService() as AirdropCenterServiceAPI }
        
        factory { DeepLinkHandler() as DeepLinkHandling }
        
        factory { DeepLinkRouter() as DeepLinkRouting }
        
        factory { UIDevice.current as DeviceInfo }
        
        factory { CrashlyticsRecorder() as MessageRecording }
        
        factory { CrashlyticsRecorder() as ErrorRecording }
        
        factory(tag: "CrashlyticsRecorder") { CrashlyticsRecorder() as Recording }
        
        factory { ExchangeClient() as ExchangeClientAPI }
        
        factory { RecoveryPhraseStatusProvider() as RecoveryPhraseStatusProviding }
        
        single { TradeLimitsMetadataService() as TradeLimitsMetadataServiceAPI }
        
        factory { SiftService() }
        
        factory { () -> FeatureAuthenticationDomain.SiftServiceAPI in
            let service: SiftService = DIKit.resolve()
            return service as FeatureAuthenticationDomain.SiftServiceAPI
        }
        
        factory { () -> PlatformKit.SiftServiceAPI in
            let service: SiftService = DIKit.resolve()
            return service as PlatformKit.SiftServiceAPI
        }
        
        single { SecondPasswordHelper() }
        
        factory { () -> SecondPasswordHelperAPI in
            let helper: SecondPasswordHelper = DIKit.resolve()
            return helper as SecondPasswordHelperAPI
        }
        
        factory { () -> SecondPasswordPresenterHelper in
            let helper: SecondPasswordHelper = DIKit.resolve()
            return helper as SecondPasswordPresenterHelper
        }
        
        factory { CustomerSupportChatClient() as CustomerSupportChatClientAPI }
        
        factory { CustomerSupportChatService() as CustomerSupportChatServiceAPI }
        
        factory { CustomerSupportChatRouter() as CustomerSupportChatRouterAPI }
        
        single { () -> SecondPasswordPromptable in
            SecondPasswordPrompter(
                secondPasswordStore: DIKit.resolve(),
                secondPasswordPrompterHelper: DIKit.resolve(),
                secondPasswordService: DIKit.resolve(),
                nativeWalletEnabled: { nativeWalletFlagEnabled() }
            )
        }
        
        single { SecondPasswordStore() as SecondPasswordStorable }
        
        single { () -> AppDeeplinkHandlerAPI in
            let appSettings: BlockchainSettings.App = DIKit.resolve()
            let isPinSet: () -> Bool = { appSettings.isPinSet }
            let deeplinkHandler = CoreDeeplinkHandler(
                markBitpayUrl: { BitpayService.shared.content = $0 },
                isBitPayURL: BitPayLinkRouter.isBitPayURL,
                isPinSet: isPinSet
            )
            let blockchainHandler = BlockchainLinksHandler(
                validHosts: BlockchainLinks.validLinks,
                validRoutes: BlockchainLinks.validRoutes
            )
            return AppDeeplinkHandler(
                deeplinkHandler: deeplinkHandler,
                blockchainHandler: blockchainHandler,
                firebaseHandler: FirebaseDeeplinkHandler()
            )
        }
        
        // MARK: ExchangeCoordinator
        
        factory { ExchangeCoordinator.shared }
        
        factory { () -> ExchangeCoordinating in
            let coordinator: ExchangeCoordinator = DIKit.resolve()
            return coordinator as ExchangeCoordinating
        }
        
        // MARK: - AuthenticationCoordinator
        
        factory { () -> AuthenticationCoordinating in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveAuthenticationCoordinating() as AuthenticationCoordinating
        }
        
        // MARK: - Dashboard
        
        factory { () -> AccountsRouting in
            let routing: TabSwapping = DIKit.resolve()
            return AccountsRouter(
                routing: routing
            )
        }
        
        factory { UIApplication.shared as AppStoreOpening }
        
        factory {
            BackupFundsRouter(
                entry: .custody,
                navigationRouter: NavigationRouter()
            ) as FeatureDashboardUI.BackupRouterAPI
        }
        
        factory { AnalyticsUserPropertyInteractor() as FeatureDashboardUI.AnalyticsUserPropertyInteracting }
        
        factory { AnnouncementPresenter() as FeatureDashboardUI.AnnouncementPresenting }
        
        factory { FiatBalanceCellProvider() as FiatBalanceCellProviding }
        
        factory { FiatBalanceCollectionViewInteractor() as FiatBalancesInteracting }
        
        factory { FiatBalanceCollectionViewPresenter(interactor: FiatBalanceCollectionViewInteractor())
            as FiatBalanceCollectionViewPresenting
        }
        
        factory { SimpleBuyAnalyticsService() as PlatformKit.SimpleBuyAnalayticsServicing }
        
        // MARK: - AppCoordinator
        
        single { LoggedInDependencyBridge() as LoggedInDependencyBridgeAPI }
        
        factory { () -> TabSwapping in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveTabSwapping() as TabSwapping
        }
        
        factory { () -> AppCoordinating in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveAppCoordinating() as AppCoordinating
        }
        
        factory { () -> FeatureDashboardUI.WalletOperationsRouting in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveWalletOperationsRouting() as FeatureDashboardUI.WalletOperationsRouting
        }
        
        factory { () -> BackupFlowStarterAPI in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveBackupFlowStarter() as BackupFlowStarterAPI
        }
        
        factory { () -> CashIdentityVerificationAnnouncementRouting in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveCashIdentityVerificationAnnouncementRouting()
            as CashIdentityVerificationAnnouncementRouting
        }
        
        factory { () -> InterestIdentityVerificationAnnouncementRouting in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveInterestIdentityVerificationAnnouncementRouting()
            as InterestIdentityVerificationAnnouncementRouting
        }
        
        factory { () -> SettingsStarterAPI in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveSettingsStarter() as SettingsStarterAPI
        }
        
        factory { () -> DrawerRouting in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveDrawerRouting() as DrawerRouting
        }
        
        factory { () -> LoggedInReloadAPI in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveLoggedInReload() as LoggedInReloadAPI
        }
        
        factory { () -> ClearOnLogoutAPI in
            EmptyClearOnLogout()
        }
        
        factory { () -> QRCodeScannerRouting in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveQRCodeScannerRouting() as QRCodeScannerRouting
        }
        
        factory { () -> ExternalActionsProviderAPI in
            let bridge: LoggedInDependencyBridgeAPI = DIKit.resolve()
            return bridge.resolveExternalActionsProvider() as ExternalActionsProviderAPI
        }
        
        // MARK: - WalletManager
        
        single { WalletManager() }
        
        factory { () -> WalletManagerAPI in
            let manager: WalletManager = DIKit.resolve()
            return manager as WalletManagerAPI
        }
        
        factory { () -> MnemonicAccessAPI in
            let app: AppProtocol = DIKit.resolve()
            let ref = BlockchainNamespace.blockchain.app.configuration.native.wallet.payload.is.enabled[].reference
            let isEnabled = try? app.remoteConfiguration.get(ref) as? Bool
            if isEnabled ?? false {
                let secondPasswordPrompter: SecondPasswordPromptable = DIKit.resolve()
                let secondPasswordIfNeeded = { () -> AnyPublisher<String?, MnemonicAccessError> in
                    secondPasswordPrompter.secondPasswordIfNeeded(type: .actionRequiresPassword)
                        .mapError { _ in MnemonicAccessError.wrongSecondPassword }
                        .eraseToAnyPublisher()
                }
                return MnemonicAccessService(
                    secondPasswordPrompter: secondPasswordIfNeeded
                )
            }
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager.wallet as MnemonicAccessAPI
        }
        
        factory { () -> WalletRepositoryProvider in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager as WalletRepositoryProvider
        }
        
        factory { () -> JSContextProviderAPI in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager as JSContextProviderAPI
        }
        
        factory { () -> WalletRecoveryVerifing in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager.wallet as WalletRecoveryVerifing
        }
        
        factory { () -> WalletConnectMetadataAPI in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager.wallet.walletConnect as WalletConnectMetadataAPI
        }
        
        // MARK: - BlockchainSettings.App
        
        single { KeychainItemSwiftWrapper() as KeychainItemWrapping }
        
        factory { LegacyPasswordProvider() as LegacyPasswordProviding }
        
        single { BlockchainSettings.App() }
        
        factory { () -> AppSettingsAPI in
            let app: BlockchainSettings.App = DIKit.resolve()
            return app as AppSettingsAPI
        }
        
        factory { () -> AppSettingsAuthenticating in
            let app: BlockchainSettings.App = DIKit.resolve()
            return app as AppSettingsAuthenticating
        }
        
        factory { () -> PermissionSettingsAPI in
            let app: BlockchainSettings.App = DIKit.resolve()
            return app
        }
        
        factory { () -> AppSettingsSecureChannel in
            let app: BlockchainSettings.App = DIKit.resolve()
            return app as AppSettingsSecureChannel
        }
        
        // MARK: - Settings
        
        factory { () -> RecoveryPhraseVerifyingServiceAPI in
            let manager: WalletManager = DIKit.resolve()
            return RecoveryPhraseVerifyingService(wallet: manager.wallet) as RecoveryPhraseVerifyingServiceAPI
        }
        
        // MARK: - AppFeatureConfigurator
        
        single {
            AppFeatureConfigurator(
                app: DIKit.resolve()
            )
        }
        
        factory { () -> FeatureFetching in
            let featureFetching: AppFeatureConfigurator = DIKit.resolve()
            return featureFetching
        }
        
        factory { () -> RxFeatureFetching in
            let featureFetching: AppFeatureConfigurator = DIKit.resolve()
            return featureFetching
        }

        factory {
            PolygonSupport(app: DIKit.resolve()) as MoneyKit.PolygonSupport
        }

        // MARK: - UserInformationServiceProvider
        
        // user state can be observed by multiple objects and the state is made up of multiple components
        // so, better have a single instance of this object.
        single { () -> UserAdapterAPI in
            UserAdapter(
                balanceDataFetcher: BalanceDataFetcher(coincore: DIKit.resolve()),
                kycTiersService: DIKit.resolve(),
                paymentMethodsService: DIKit.resolve(),
                productsService: DIKit.resolve(),
                ordersService: DIKit.resolve()
            )
        }
        
        factory { () -> SettingsServiceAPI in
            let completeSettingsService: CompleteSettingsServiceAPI = DIKit.resolve()
            return completeSettingsService
        }
        
        factory { () -> SettingsServiceCombineAPI in
            let settings: SettingsServiceAPI = DIKit.resolve()
            return settings as SettingsServiceCombineAPI
        }
        
        factory { () -> FiatCurrencyServiceAPI in
            let completeSettingsService: CompleteSettingsServiceAPI = DIKit.resolve()
            return completeSettingsService
        }
        
        factory { () -> SupportedFiatCurrenciesServiceAPI in
            let completeSettingsService: CompleteSettingsServiceAPI = DIKit.resolve()
            return completeSettingsService
        }
        
        factory { () -> MobileSettingsServiceAPI in
            let completeSettingsService: CompleteSettingsServiceAPI = DIKit.resolve()
            return completeSettingsService
        }
        
        // MARK: - BlockchainDataRepository
        
        factory { BlockchainDataRepository() as DataRepositoryAPI }
        
        // MARK: - Ethereum Wallet
        
        factory { () -> EthereumWalletBridgeAPI in
            let manager: WalletManager = DIKit.resolve()
            return manager.wallet.ethereum
        }
        
        factory { () -> EthereumWalletAccountBridgeAPI in
            let manager: WalletManager = DIKit.resolve()
            return manager.wallet.ethereum
        }
        
        // MARK: - Stellar Wallet
        
        factory { StellarWallet() as StellarWalletBridgeAPI }
        
        factory { () -> BitcoinWalletBridgeAPI in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager.wallet.bitcoin
        }
        
        factory { () -> BitcoinChainSendBridgeAPI in
            let walletManager: WalletManager = DIKit.resolve()
            return walletManager.wallet.bitcoin
        }
        
        single { BitcoinCashWallet() as BitcoinCashWalletBridgeAPI }
        
        // MARK: Wallet Upgrade
        
        factory { WalletUpgrading() as WalletUpgradingAPI }
        
        // MARK: Remote Notifications
        
        factory { ExternalNotificationServiceProvider() as ExternalNotificationProviding }
        
        factory { () -> RemoteNotificationEmitting in
            let relay: RemoteNotificationRelay = DIKit.resolve()
            return relay as RemoteNotificationEmitting
        }
        
        factory { () -> RemoteNotificationBackgroundReceiving in
            let relay: RemoteNotificationRelay = DIKit.resolve()
            return relay as RemoteNotificationBackgroundReceiving
        }
        
        single {
            RemoteNotificationRelay(
                app: DIKit.resolve(),
                cacheSuite: DIKit.resolve(),
                userNotificationCenter: UNUserNotificationCenter.current(),
                messagingService: Messaging.messaging(),
                secureChannelNotificationRelay: DIKit.resolve()
            )
        }
        
        // MARK: Helpers
        
        factory { UIApplication.shared as ExternalAppOpener }
        factory { UIApplication.shared as URLOpener }
        
        // MARK: KYC Module
        
        factory { () -> FeatureSettingsUI.KYCRouterAPI in
            KYCAdapter()
        }
        
        factory { () -> FeatureKYCDomain.EmailVerificationAPI in
            EmailVerificationAdapter(settingsService: DIKit.resolve())
        }
        
        factory { () -> PlatformUIKit.TierUpgradeRouterAPI in
            KYCAdapter()
        }
        
        // MARK: Onboarding Module
        
        // this must be kept in memory because of how PlatformUIKit.Router works, otherwise the flow crashes.
        single { () -> FeatureOnboardingUI.OnboardingRouterAPI in
            FeatureOnboardingUI.OnboardingRouter()
        }
        
        factory { () -> FeatureOnboardingUI.TransactionsRouterAPI in
            TransactionsAdapter(
                router: DIKit.resolve(),
                coincore: DIKit.resolve()
            )
        }
        
        factory { () -> FeatureOnboardingUI.KYCRouterAPI in
            KYCAdapter()
        }
        
        // MARK: Transactions Module
        
        factory { () -> PaymentMethodsLinkingAdapterAPI in
            PaymentMethodsLinkingAdapter()
        }
        
        factory { () -> TransactionsAdapterAPI in
            TransactionsAdapter(
                router: DIKit.resolve(),
                coincore: DIKit.resolve()
            )
        }
        
        factory { () -> PlatformUIKit.KYCRouting in
            KYCAdapter()
        }
        
        factory { () -> FeatureSettingsUI.PaymentMethodsLinkerAPI in
            PaymentMethodsLinkingAdapter()
        }
        
        factory { () -> FeatureTransactionUI.UserActionServiceAPI in
            TransactionUserActionService(userService: DIKit.resolve())
        }
        
        factory { () -> FeatureTransactionDomain.TransactionRestrictionsProviderAPI in
            TransactionUserActionService(userService: DIKit.resolve())
        }
        
        // MARK: FeatureAuthentication Module
        
        factory { () -> AutoWalletPairingServiceAPI in
            let manager: WalletManager = DIKit.resolve()
            return AutoWalletPairingService(
                walletPayloadService: DIKit.resolve(),
                walletPairingRepository: DIKit.resolve(),
                walletCryptoService: DIKit.resolve(),
                parsingService: DIKit.resolve()
            ) as AutoWalletPairingServiceAPI
        }
        
        factory { () -> GuidServiceAPI in
            GuidService(
                sessionTokenRepository: DIKit.resolve(),
                guidRepository: DIKit.resolve()
            )
        }
        
        factory { () -> SessionTokenServiceAPI in
            sessionTokenServiceFactory(
                sessionRepository: DIKit.resolve()
            )
        }
        
        factory { () -> SMSServiceAPI in
            SMSService(
                smsRepository: DIKit.resolve(),
                credentialsRepository: DIKit.resolve(),
                sessionTokenRepository: DIKit.resolve()
            )
        }
        
        factory { () -> TwoFAWalletServiceAPI in
            let manager: WalletManager = DIKit.resolve()
            return TwoFAWalletService(
                repository: DIKit.resolve(),
                walletRepository: manager.repository,
                walletRepo: DIKit.resolve(),
                nativeWalletFlagEnabled: { nativeWalletFlagEnabled() }
            )
        }
        
        factory { () -> WalletPayloadServiceAPI in
            let manager: WalletManager = DIKit.resolve()
            return WalletPayloadService(
                repository: DIKit.resolve(),
                walletRepository: manager.repository,
                walletRepo: DIKit.resolve(),
                credentialsRepository: DIKit.resolve(),
                nativeWalletEnabledUse: nativeWalletEnabledUseImpl
            )
        }
        
        factory { () -> LoginServiceAPI in
            LoginService(
                payloadService: DIKit.resolve(),
                twoFAPayloadService: DIKit.resolve(),
                repository: DIKit.resolve()
            )
        }
        
        factory { () -> EmailAuthorizationServiceAPI in
            EmailAuthorizationService(guidService: DIKit.resolve()) as EmailAuthorizationServiceAPI
        }
        
        factory { () -> DeviceVerificationServiceAPI in
            let sessionTokenRepository: SessionTokenRepositoryAPI = DIKit.resolve()
            return DeviceVerificationService(
                sessionTokenRepository: sessionTokenRepository
            ) as DeviceVerificationServiceAPI
        }
        
        factory { RecaptchaClient(siteKey: AuthenticationKeys.googleRecaptchaSiteKey) }
        
        factory { GoogleRecaptchaService() as GoogleRecaptchaServiceAPI }
        
        // MARK: Analytics
        
        single { () -> AnalyticsKit.GuidRepositoryAPI in
            let guidRepository: BlockchainSettings.App = DIKit.resolve()
            return guidRepository as AnalyticsKit.GuidRepositoryAPI
        }
        
        single { () -> AnalyticsEventRecorderAPI in
            let firebaseAnalyticsServiceProvider = FirebaseAnalyticsServiceProvider()
            let userAgent = UserAgentProvider().userAgent ?? ""
            let nabuAnalyticsServiceProvider = NabuAnalyticsProvider(
                platform: .wallet,
                basePath: BlockchainAPI.shared.apiUrl,
                userAgent: userAgent,
                tokenProvider: DIKit.resolve(),
                guidProvider: DIKit.resolve()
            )
            return AnalyticsEventRecorder(analyticsServiceProviders: [
                firebaseAnalyticsServiceProvider,
                nabuAnalyticsServiceProvider
            ])
        }
        
        // MARK: Account Picker
        
        factory { () -> AccountPickerViewControllable in
            let controller = FeatureAccountPickerControllableAdapter()
            return controller as AccountPickerViewControllable
        }
        
        // MARK: Open Banking
        
        single { () -> OpenBanking in
            let builder: NetworkKit.RequestBuilder = DIKit.resolve(tag: DIKitContext.retail)
            let adapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve(tag: DIKitContext.retail)
            let client = OpenBankingClient(
                app: DIKit.resolve(),
                requestBuilder: builder,
                network: adapter.network
            )
            return OpenBanking(app: DIKit.resolve(), banking: client)
        }
        
        // MARK: Coin View
        
        single { () -> HistoricalPriceClientAPI in
            let requestBuilder: NetworkKit.RequestBuilder = DIKit.resolve()
            let networkAdapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve()
            return HistoricalPriceClient(
                request: requestBuilder,
                network: networkAdapter
            )
        }
        
        single { () -> HistoricalPriceRepositoryAPI in
            HistoricalPriceRepository(DIKit.resolve())
        }
        
        single { () -> RatesClientAPI in
            let requestBuilder: NetworkKit.RequestBuilder = DIKit.resolve(tag: DIKitContext.retail)
            let networkAdapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve(tag: DIKitContext.retail)
            return RatesClient(
                networkAdapter: networkAdapter,
                requestBuilder: requestBuilder
            )
        }
        
        single { () -> RatesRepositoryAPI in
            RatesRepository(DIKit.resolve())
        }
        
        single { () -> WatchlistRepositoryAPI in
            WatchlistRepository(
                WatchlistClient(
                    networkAdapter: DIKit.resolve(tag: DIKitContext.retail),
                    requestBuilder: DIKit.resolve(tag: DIKitContext.retail)
                )
            )
        }
        
        // MARK: Feature Product
        
        factory { () -> FeatureProductsDomain.ProductsServiceAPI in
            ProductsService(
                repository: ProductsRepository(
                    client: ProductsAPIClient(
                        networkAdapter: DIKit.resolve(tag: DIKitContext.retail),
                        requestBuilder: DIKit.resolve(tag: DIKitContext.retail)
                    )
                ),
                featureFlagsService: DIKit.resolve()
            )
        }

        // MARK: Feature NFT

        factory { () -> FeatureNFTDomain.AssetProviderServiceAPI in
            let repository: EthereumWalletAccountRepositoryAPI = DIKit.resolve()
            let publisher = repository
                .defaultAccount
                .map(\.publicKey)
                .eraseError()
            return AsssetProviderService(
                repository: AssetProviderRepository(
                    client: FeatureNFTData.APIClient(
                        networkAdapter: DIKit.resolve(tag: DIKitContext.retail),
                        requestBuilder: DIKit.resolve(tag: DIKitContext.retail)
                    )
                ),
                ethereumWalletAddressPublisher: publisher
            )
        }

        // MARK: Feature Crypto Domain
        
        factory { () -> SearchDomainRepositoryAPI in
            let builder: NetworkKit.RequestBuilder = DIKit.resolve()
            let adapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve()
            let client = SearchDomainClient(networkAdapter: adapter, requestBuilder: builder)
            return SearchDomainRepository(apiClient: client)
        }
        
        factory { () -> OrderDomainRepositoryAPI in
            let builder: NetworkKit.RequestBuilder = DIKit.resolve(tag: DIKitContext.retail)
            let adapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve(tag: DIKitContext.retail)
            let client = OrderDomainClient(networkAdapter: adapter, requestBuilder: builder)
            return OrderDomainRepository(apiClient: client)
        }
        
        factory { () -> ClaimEligibilityRepositoryAPI in
            let builder: NetworkKit.RequestBuilder = DIKit.resolve(tag: DIKitContext.retail)
            let adapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve(tag: DIKitContext.retail)
            let client = ClaimEligibilityClient(networkAdapter: adapter, requestBuilder: builder)
            return ClaimEligibilityRepository(apiClient: client)
        }
        
        // MARK: Feature Notification Preferences
        
        factory { () -> NotificationPreferencesRepositoryAPI in
            let builder: NetworkKit.RequestBuilder = DIKit.resolve(tag: DIKitContext.retail)
            let adapter: NetworkKit.NetworkAdapterAPI = DIKit.resolve(tag: DIKitContext.retail)
            let client = NotificationPreferencesClient(networkAdapter: adapter, requestBuilder: builder)
            return NotificationPreferencesRepository(client: client) as NotificationPreferencesRepositoryAPI}
        
        // MARK: Pulse Network Debugging
        
        single {
            PulseNetworkDebugLogger() as NetworkDebugLogger
        }
        
        single {
            PulseNetworkDebugScreenProvider() as NetworkDebugScreenProvider
        }
        
        single { app }

        factory { () -> NativeWalletFlagEnabled in
            let app: AppProtocol = DIKit.resolve()
            let flag: Tag.Event = BlockchainNamespace.blockchain.app.configuration.native.wallet.payload.is.enabled
            return NativeWalletFlagEnabled(
                app.publisher(for: flag, as: Bool.self)
                    .prefix(1)
                    .replaceError(with: false)
            )
        }
    }
}
