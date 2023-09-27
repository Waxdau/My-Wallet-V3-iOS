import AnalyticsKit
@_exported import BlockchainNamespace
import DIKit
import ErrorsUI
import FeatureAppDomain
import FeatureAppUI
import FeatureAttributionDomain
import FeatureAuthenticationDomain
import FeatureCoinUI
import FeatureCustomerSupportUI
import FeatureDashboardDomain
import FeatureExternalTradingMigrationDomain
import FeatureKYCDomain
import FeatureKYCUI
import FeatureProductsDomain
import FeatureReferralDomain
import FeatureReferralUI
import FeatureSettingsDomain
import FeatureStakingDomain
import FeatureTransactionUI
import FeatureUserTagSyncDomain
import FeatureWalletConnectDomain
import FeatureWireTransfer
import FirebaseCore
import FirebaseInstallations
import FirebaseProtocol
import FirebaseRemoteConfig
import FraudIntelligence
import ObservabilityKit
import PlatformKit
import ToolKit
import UIKit

let app: AppProtocol = App(
    remoteConfiguration: Session.RemoteConfiguration(
        remote: FirebaseRemoteConfig.RemoteConfig.remoteConfig(),
        default: embbedAppConfiguration + [
            blockchain.app.configuration.manual.login.is.enabled: BuildFlag.isInternal
        ]
    )
)

private var embbedAppConfiguration: Session.RemoteConfiguration.Default {
    try! Session.RemoteConfiguration.Default(blockchain.app.configuration.json(in: .main) as Any)
}

extension AppProtocol {

    func bootstrap(
        analytics recorder: AnalyticsEventRecorderAPI = resolve(),
        deepLink: DeepLinkCoordinator = resolve(),
        referralService: ReferralServiceAPI = resolve(),
        attributionService: AttributionServiceAPI = resolve(),
        performanceTracing: PerformanceTracingServiceAPI = resolve(),
        userTagService: UserTagServiceAPI = resolve(),
        productsService: ProductsServiceAPI = resolve()
    ) {
        clientObservers.insert(ApplicationStateObserver(app: self))
        clientObservers.insert(AppHapticObserver(app: self))
        clientObservers.insert(AppAnalyticsObserver(app: self))
        clientObservers.insert(AppNotificationCenterObservation(app: self))
        clientObservers.insert(resolve() as AppAnalyticsTraitRepository)
        clientObservers.insert(KYCExtraQuestionsObserver(app: self))
        clientObservers.insert(NabuUserSessionObserver(app: self))
        clientObservers.insert(CoinViewAnalyticsObserver(app: self, analytics: recorder))
        clientObservers.insert(CoinViewObserver(app: self))
        clientObservers.insert(BuyOtherCryptoObserver(app: self))
        clientObservers.insert(UpsellPassiveRewardsObserver(app: self))
        clientObservers.insert(ReferralAppObserver(app: self, referralService: referralService))
        clientObservers.insert(AttributionAppObserver(app: self, attributionService: attributionService))
        clientObservers.insert(UserTagObserver(app: self, userTagSyncService: userTagService))
        clientObservers.insert(SuperAppIntroObserver(app: self))
        clientObservers.insert(PlaidLinkObserver(app: self))
        clientObservers.insert(DefaultAppModeObserver(app: self, productsService: resolve()))
        clientObservers.insert(deepLink)
        clientObservers.insert(DashboardAnnouncementsObserver(app: self, backupFundsRouter: resolve()))
        #if DEBUG || ALPHA_BUILD || INTERNAL_BUILD
        clientObservers.insert(PulseBlockchainNamespaceEventLogger(app: self))
        #endif
        clientObservers.insert(PerformanceTracingObserver(app: self, service: performanceTracing))
        clientObservers.insert(NabuGatewayPriceObserver(app: self))
        clientObservers.insert(EarnObserver(self))
        clientObservers.insert(VGSAddCardObserver(app: self))
        clientObservers.insert(SimpleBuyPairsNAPIRepository(self))
        clientObservers.insert(WalletConnectPairingsObserver(app: self))
        clientObservers.insert(LaunchKYCClientObserver())
        clientObservers.insert(SweepAddressesObserver(app: self))
        clientObservers.insert(ResubmitResidentialInformation())

        let intercom = (
            apiKey: Bundle.main.plist.intercomAPIKey[] as String?,
            appId: Bundle.main.plist.intercomAppId[] as String?
        )

        if let apiKey = intercom.apiKey, let appId = intercom.appId {
            clientObservers.insert(
                CustomerSupportObserver<Intercom>(
                    app: self,
                    apiKey: apiKey,
                    appId: appId,
                    open: UIApplication.shared.open,
                    unreadNotificationName: NSNotification.Name.IntercomUnreadConversationCountDidChange
                )
            )
        }

        #if canImport(MobileIntelligence)
        clientObservers.insert(Sardine<MobileIntelligence>(self, isProduction: BuildFlag.isProduction))
        #endif

        Task {
            let result = try await Installations.installations().authTokenForcingRefresh(true)
            state.transaction { state in
                state.set(blockchain.user.token.firebase.installation, to: result.authToken)
            }
        }

        Task {
            do {
                try await NewsNAPIRepository().register()
                try await CoincoreNAPI(app: resolve(), coincore: resolve(), currenciesService: resolve()).register()
                try await WireTransferNAPI(self).register()
                try await TradingPairsNAPI().register()
                try await UserProductsRepository(app: self).register()
                try await ExternalTradingMigrationRepository().register()
                let kycRepository: KYCSSNRepository = DIKit.resolve()
                try await kycRepository.register()
            } catch {
                post(error: error)
                #if DEBUG
                assertionFailure("⛔️ \(error)")
                #endif
            }
        }
    }

    /// Adds any observers that need to be on `AppDelegate.didFinishLaunching` method
    func didFinishLaunching(window: UIWindow) {
        clientObservers.insert(ThemeSettingsObserver(app: self, window: window))
    }
}

extension FirebaseRemoteConfig.RemoteConfig: RemoteConfiguration_p {}
extension FirebaseRemoteConfig.ConfigUpdateListenerRegistration: ConfigUpdateListenerRegistration_p {}
extension FirebaseRemoteConfig.RemoteConfigUpdate: RemoteConfigUpdate_p {}
extension FirebaseRemoteConfig.RemoteConfigValue: RemoteConfigurationValue_p {}
extension FirebaseRemoteConfig.RemoteConfigFetchStatus: RemoteConfigurationFetchStatus_p {}
extension FirebaseRemoteConfig.RemoteConfigSource: RemoteConfigurationSource_p {}

#if canImport(MobileIntelligence)
import class MobileIntelligence.MobileIntelligence
import class MobileIntelligence.Options
import class MobileIntelligence.OptionsBuilder
import struct MobileIntelligence.Response
import struct MobileIntelligence.UpdateOptions

public typealias _OptionsBuilder = OptionsBuilder

extension MobileIntelligence: MobileIntelligence_p {
    public typealias OptionsBuilder = _OptionsBuilder
    public static func start(withOptions options: Options) -> AnyObject {
        MobileIntelligence(withOptions: options)
    }
}

extension Options: MobileIntelligenceOptions_p {}
extension Response: MobileIntelligenceResponse_p {}
extension UpdateOptions: MobileIntelligenceUpdateOptions_p {}
extension OptionsBuilder: MobileIntelligenceOptionsBuilder_p {
    public static func new() -> OptionsBuilder { OptionsBuilder() }
}

#endif

#if canImport(Intercom)
import class Intercom.ICMUserAttributes
import class Intercom.Intercom
extension Intercom: Intercom_p {
    public static func showHelpCenter() {
        Intercom.present()
    }

    public static func showMessenger() {
        Intercom.present(.messages)
    }
}

extension ICMUserAttributes: IntercomUserAttributes_p {}
#endif

extension Tag.Event {

    fileprivate func json(in bundle: Bundle) -> Any? {
        guard let path = Bundle.main.path(forResource: description, ofType: "json") else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }
}
