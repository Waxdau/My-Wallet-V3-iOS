import BlockchainUI
import Dependencies
import DIKit
import FeatureCoinDomain
import FeatureCoinUI
import FeatureCustodialOnboarding
import FeatureDashboardDomain
import FeatureDashboardUI
import FeatureDexUI
import FeatureExternalTradingMigrationUI
import FeatureKYCUI
import FeatureNFTUI
import FeatureQRCodeScannerUI
import FeatureQuickActions
import FeatureReceiveUI
import FeatureReferralDomain
import FeatureReferralUI
import FeatureSettingsUI
import FeatureStakingUI
import FeatureTransactionDomain
import FeatureTransactionEntryUI
import FeatureTransactionUI
import FeatureWalletConnectUI
import FeatureWireTransfer
import FeatureWithdrawalLocksDomain
import FeatureWithdrawalLocksUI
import PlatformKit
import RemoteNotificationsKit
import SafariServices
import UnifiedActivityDomain
import UnifiedActivityUI

@MainActor
public struct SiteMap {
    let app: AppProtocol

    public init(app: AppProtocol) {
        self.app = app
    }

    @ViewBuilder public func view(
        for ref: Tag.Reference,
        in context: Tag.Context = [:]
    ) throws -> some View {
        let story = try ref.tag.as(blockchain.ux.type.story)
        switch ref.tag {
        case blockchain.ux.user.rewards:
            RewardsView()
        case blockchain.ux.buy.another.asset:
            BuyOtherCryptoView()
        case blockchain.ux.upsell.after.successful.swap:
            UpsellPassiveRewardsView()
        case blockchain.ux.nft, isDescendant(of: blockchain.ux.nft):
            try NFTSiteMap().view(for: ref, in: context)
        case blockchain.ux.web:
            try SafariView(url: ref.context[blockchain.ux.web].decode())
                .ignoresSafeArea(.container, edges: .bottom)
        case blockchain.ux.payment.method.wire.transfer, isDescendant(of: blockchain.ux.payment.method.wire.transfer):
            try FeatureWireTransfer.SiteMap(app: app).view(for: ref, in: context)
        case blockchain.ux.user.activity.all:
            let typeForAppMode: PresentedAssetType = app.currentMode == .trading ? .custodial : .nonCustodial
            let modelOrDefault = (try? context.decode(blockchain.ux.user.activity.all.model, as: PresentedAssetType.self)) ?? typeForAppMode
            let reducer = AllActivityScene(
                activityRepository: resolve(),
                custodialActivityRepository: resolve(),
                app: app
            )
            AllActivitySceneView(
                store: Store(
                    initialState: .init(with: modelOrDefault),
                    reducer: { reducer }
                )
            )
        case blockchain.ux.user.assets.all:
            let initialState = try AllAssetsScene.State(with: context.decode(blockchain.ux.user.assets.all.model))
            let reducer = AllAssetsScene(
                app: app
            )
            AllAssetsSceneView(store: Store(
                initialState: initialState,
                reducer: { reducer }
            ))
        case blockchain.ux.activity.detail:
            let initialState = try ActivityDetailScene.State(activityEntry: context.decode(blockchain.ux.activity.detail.model))
            ActivityDetailSceneView(
                store: Store(
                    initialState: initialState,
                    reducer: {
                        ActivityDetailScene(
                            app: resolve(),
                            activityDetailsService: resolve(),
                            custodialActivityDetailsService: resolve()
                        )
                    }
                )
            )
        case blockchain.ux.dashboard.recurring.buy.manage,
            blockchain.ux.recurring.buy.onboarding,
            isDescendant(of: blockchain.ux.asset.recurring):
            try recurringBuy(for: ref, in: context)
        case blockchain.ux.asset:
            let currency: CryptoCurrency = try (ref.context[blockchain.ux.asset.id] ?? context[blockchain.ux.asset.id]).decode()
            CoinAdapterView(
                cryptoCurrency: currency,
                dismiss: {
                    app.post(value: true, of: story.article.plain.navigation.bar.button.close.tap.then.close.key(to: ref.context))
                }
            )
        case blockchain.ux.withdrawal.locks:
            try WithdrawalLocksDetailsView(
                withdrawalLocks: context.decode(
                    blockchain.ux.withdrawal.locks.info,
                    as: WithdrawalLocks.self
                )
            )
        case blockchain.ux.transaction, isDescendant(of: blockchain.ux.transaction):
            try transaction(for: ref, in: context)
        case blockchain.ux.earn, isDescendant(of: blockchain.ux.earn):
            try Earn(app).view(for: ref, in: context)
        case blockchain.ux.dashboard.fiat.account.action.sheet:
            let balanceInfo = try context[blockchain.ux.dashboard.fiat.account.action.sheet.asset].decode(AssetBalanceInfo.self)
            FiatActionSheet(assetBalanceInfo: balanceInfo)
        case blockchain.ux.frequent.action.brokerage.more:
            let quickActions = try context[blockchain.ux.frequent.action.brokerage.more.actions].decode([QuickAction].self)
            MoreQuickActionSheet(tag: blockchain.ux.frequent.action.brokerage.more, actionsList: quickActions)
        case blockchain.ux.scan.QR:
            QRCodeScannerView(
                app: app,
                secureChannelRouter: resolve(),
                walletConnectService: resolve(),
                tabSwapping: resolve()
            )
            .identity(blockchain.ux.scan.QR)
            .ignoresSafeArea()
        case blockchain.ux.currency.receive.select.asset:
              ReceiveEntryView()
                .app(app)
        case blockchain.ux.currency.receive.address:
            ReceiveAddressView()
        case blockchain.ux.user.account:
            AccountView()
                .identity(blockchain.ux.user.account)
                .ignoresSafeArea(.container, edges: .bottom)
        case blockchain.ux.referral.details.screen:
            let model = try context[blockchain.ux.referral.details.screen.info].decode(Referral.self)
            ReferFriendView(store: Store(
                initialState: .init(referralInfo: model),
                reducer: {
                    ReferFriendReducer(
                        mainQueue: .main,
                        analyticsRecorder: resolve()
                    )
                }
            ))
            .identity(blockchain.ux.referral)
            .ignoresSafeArea()
        case blockchain.ux.wallet.connect, isDescendant(of: blockchain.ux.wallet.connect):
            try WalletConnectSiteMap()
                .view(for: ref, in: context)
        case blockchain.ux.news.story:
            try NewsStoryView(
                api: context.decode(blockchain.ux.news, as: Tag.self).as(blockchain.api.news.type.list)
            )
        case blockchain.ux.dashboard.defi.balances.failure.sheet:
            let message = try context.decode(blockchain.ux.dashboard.defi.balances.failure.sheet.networks, as: String.self)
            BalancesNotLoadingSheet(networksFailing: message)
        case blockchain.ux.tooltip:
            TooltipView(
                title: context[blockchain.ux.tooltip.title].as(String.self) ?? "",
                message: context[blockchain.ux.tooltip.body].as(String.self) ?? "",
                dismiss: {
                    app.post(event: blockchain.ux.tooltip.article.plain.navigation.bar.button.close.tap, context: context)
                }
            )
            .batch {
                set(blockchain.ux.tooltip.article.plain.navigation.bar.button.close.tap.then.close, to: true)
            }
        case blockchain.ux.error:
            ErrorView(
                ux: context[blockchain.ux.error].as(UX.Error.self) ?? UX.Error(error: nil),
                dismiss: {
                    app.post(event: blockchain.ux.error.article.plain.navigation.bar.button.close.tap, context: context)
                }
            )
            .batch {
                set(blockchain.ux.error.article.plain.navigation.bar.button.close.tap.then.close, to: true)
            }
        case blockchain.ux.currency.exchange, isDescendant(of: blockchain.ux.currency.exchange):
            try FeatureDexUI.SiteMap(app: app).view(for: ref, in: context)
        case blockchain.ux.kyc, isDescendant(of: blockchain.ux.kyc):
            try FeatureKYCUI.SiteMap(app: app).view(for: ref, in: context)
        case blockchain.ux.settings, isDescendant(of: blockchain.ux.settings):
            try FeatureSettingsUI.SettingsSiteMap().view(for: ref, in: context)
        case isDescendant(of: blockchain.ux.user.custodial):
            try FeatureCustodialOnboarding.SiteMap().view(for: ref, in: context)
        case blockchain.ux.onboarding.notification.authorization.display, isDescendant(of: blockchain.ux.onboarding.notification.authorization.display):
            RemoteNotificationAuthorizationView()
        case blockchain.ux.sweep.imported.addresses.transfer:
            SweepImportedAddressesView()
                .app(app)
        case blockchain.ux.sweep.imported.addresses.no.action:
            SweepImportedAddressesNoActionView()
                .app(app)

        case blockchain.ux.dashboard.external.trading.migration:
            ExternalTradingMigrationView(
                store: Store(
                    initialState: .init(),
                    reducer: {
                        ExternalTradingMigration(
                            app: app,
                            externalTradingMigrationService: resolve()
                        )
                    }
                )
            )

        default:
            throw Error(message: "No view", tag: ref, context: context)
        }
    }
}

extension SiteMap {

    @MainActor
    @ViewBuilder
    func recurringBuy(
        for ref: Tag.Reference,
        in context: Tag.Context = [:]
    ) throws -> some View {
        switch ref.tag {
        case blockchain.ux.recurring.buy.onboarding:
            let location = try context[blockchain.ux.recurring.buy.onboarding.location].decode(RecurringBuyListView.Location.self)
            RecurringBuyOnboardingView(location: location)
        case blockchain.ux.asset.recurring.buy.summary:
            let asset: String = try ref[blockchain.ux.asset.id].decode(String.self)
            let buyId: String = try ref[blockchain.ux.asset.recurring.buy.summary.id].decode(String.self)
            let buy: FeatureCoinDomain.RecurringBuy = try context.decode(
                blockchain.ux.asset[asset].recurring.buy.summary[buyId].model,
                as: FeatureCoinDomain.RecurringBuy.self
            )
            let cancelRecurringBuy: CancelRecurringBuyRepositoryAPI = resolve()
            RecurringBuySummaryView(buy: buy)
                .provideCancelRecurringBuyService(.init(processCancel: cancelRecurringBuy.cancelRecurringBuyWithId))
                .context(ref.context)
        case blockchain.ux.dashboard.recurring.buy.manage:
            RecurringBuyManageView()
        default:
            throw Error(message: "No view", tag: ref, context: context)
        }
    }
}

extension SiteMap {

    @MainActor
    struct Earn {

        let app: AppProtocol

        init(_ app: AppProtocol) { self.app = app }

        @MainActor @ViewBuilder func view(
            for ref: Tag.Reference,
            in context: Tag.Context = [:]
        ) throws -> some View {
            switch ref {
            case blockchain.ux.earn.portfolio.product.asset.summary:
                try EarnSummaryView()
                    .context(
                        [
                            blockchain.user.earn.product.id: ref.context[blockchain.ux.earn.portfolio.product.id].or(throw: "No product"),
                            blockchain.user.earn.product.asset.id: ref.context[blockchain.ux.earn.portfolio.product.asset.id].or(throw: "No asset")
                        ]
                    )
            case blockchain.ux.earn.discover.product.not.eligible:
                try EarnProductNotEligibleView(
                    story: ref[].as(blockchain.ux.earn.type.hub.product.not.eligible)
                )
                .context(
                    [
                        blockchain.ux.earn.discover.product.id: context[blockchain.user.earn.product.id].or(throw: "No product"),
                        blockchain.ux.earn.discover.product.asset.id: context[blockchain.user.earn.product.asset.id].or(throw: "No product")
                    ]
                )
            case blockchain.ux.earn.portfolio.product.asset.no.balance, blockchain.ux.earn.discover.product.asset.no.balance:
                try EarnProductAssetNoBalanceView(
                    story: ref[].as(blockchain.ux.earn.type.hub.product.asset.no.balance)
                )
                .context(
                    [
                        blockchain.ux.earn.discover.product.id: context[blockchain.user.earn.product.id].or(throw: "No product"),
                        blockchain.ux.earn.discover.product.asset.id: context[blockchain.user.earn.product.asset.id].or(throw: "No product")
                    ]
                )
            default:
                throw Error(message: "No view", tag: ref, context: context)
            }
        }
    }
}

extension SiteMap {

    struct Error: Swift.Error {
        let message: String
        let tag: Tag.Reference
        let context: Tag.Context
    }
}

extension SiteMap.Error: LocalizedError {
    var errorDescription: String? { "\(tag.string): \(message)" }
}

extension View {
    @ViewBuilder
    func identity(_ tag: Tag.Event, in context: Tag.Context = [:]) -> some View {
        id(tag.description)
            .accessibility(identifier: tag.description)
    }
}

public struct SafariView: UIViewControllerRepresentable {

    @Binding var url: URL

    public init(url: URL) {
        _url = .constant(url)
    }

    public init(url: Binding<URL>) {
        _url = url
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        safariViewController.preferredControlTintColor = UIColor(Color.accentColor)
        safariViewController.dismissButtonStyle = .close
        return safariViewController
    }

    public func updateUIViewController(_ safariViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}
