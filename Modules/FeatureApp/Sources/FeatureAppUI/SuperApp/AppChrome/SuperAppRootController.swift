//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import DIKit
import FeatureAppDomain
import FeatureAuthenticationDomain
import FeatureBackupRecoveryPhraseUI
import FeatureDashboardUI
import FeatureOnboardingUI
import FeaturePin
import FeatureSuperAppIntroUI
import FeatureTransactionUI
import FeatureWalletConnectDomain
import FeatureWalletConnectUI
import MoneyKit
import PlatformKit
import PlatformUIKit
import StoreKit
import SwiftUI
import ToolKit
import UIKit

public protocol SuperAppRootControllable: UIViewController {
    func clear()
}

@available(iOS 15, *)
public final class SuperAppRootController: UIHostingController<SuperAppContainerChrome>, SuperAppRootControllable {

    let app: AppProtocol
    let global: ViewStore<LoggedIn.State, LoggedIn.Action>

    let siteMap: SiteMap

    var appStoreReview: AnyCancellable?
    var displayPostSignInOnboardingFlow: AnyCancellable?
    var displaySendCryptoScreen: AnyCancellable?
    var displayPostSignUpOnboardingFlow: AnyCancellable?

    var bag: Set<AnyCancellable> = []

    // MARK: Dependencies

    @LazyInject var alertViewPresenter: AlertViewPresenterAPI
    @LazyInject var backupRouter: RecoveryPhraseBackupRouterAPI
    @LazyInject var coincore: CoincoreAPI
    @LazyInject var eligibilityService: EligibilityServiceAPI
    @LazyInject var featureFlagService: FeatureFlagsServiceAPI
    @LazyInject var fiatCurrencyService: FiatCurrencyServiceAPI
    @LazyInject var kycRouter: PlatformUIKit.KYCRouting
    @LazyInject var onboardingRouter: FeatureOnboardingUI.OnboardingRouterAPI
    @LazyInject var tiersService: KYCTiersServiceAPI
    @LazyInject var transactionsRouter: FeatureTransactionUI.TransactionsRouterAPI
    @Inject var walletConnectService: WalletConnectServiceAPI
    @Inject var walletConnectServiceV2: WalletConnectServiceV2API
    @Inject var walletConnectRouter: WalletConnectRouterAPI
    @Inject var walletConnectObserver: WalletConnectObserver

    var pinRouter: PinRouter?

    lazy var bottomSheetPresenter = BottomSheetPresenting()

    public init(
        store global: Store<LoggedIn.State, LoggedIn.Action>,
        app: AppProtocol,
        siteMap: SiteMap
    ) {
        self.global = ViewStore(global)
        self.app = app
        self.siteMap = siteMap
        super.init(rootView: SuperAppContainerChrome(app: app, isSmallDevice: isSmallDevice()))

        subscribeFrequentActions(to: app)

        setupNavigationObservers()
        observeDismissals()
    }

    public func clear() {
        bag.removeAll()
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        subscribe(to: global)
        appStoreReview = NotificationCenter.default.publisher(for: .transaction)
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let scene = self?.view.window?.windowScene else { return }
#if INTERNAL_BUILD
                scene.peek("🧾 Show App Store Review Prompt!")
#else
                SKStoreReviewController.requestReview(in: scene)
#endif
            }
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    // The following fixes SwiftUI's gesture handling that can get messed up when applying
    // transforms and/or frame changes during an interactive presentation. This resets
    // SwiftUI's geometry in a "clean way", fixing hit testing.
    // source: https://github.com/nathantannar4/Transmission/blob/main/Sources/Transmission/Sources/View/PresentationLinkAdapter.swift#L397-L399
    private func observeDismissals() {
        alterDismissOnViewControllers()
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIApplication.keyboardDidHideNotification),
            NotificationCenter.default.publisher(for: UIViewController.controllerDidDismiss)
        )
        .delay(for: .milliseconds(200), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else {
                return
            }
            invalidateFrames(controller: self)
        }
        .store(in: &bag)
    }
}

@available(iOS 15, *)
extension SuperAppRootController {
    func subscribeFrequentActions(to app: AppProtocol) {
        let observers = [
            app.on(blockchain.ux.frequent.action.buy)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleBuyCrypto(account: nil)
                }),
            app.on(blockchain.ux.frequent.action.sell)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleSellCrypto(account: nil)
                }),
            app.on(blockchain.ux.frequent.action.currency.exchange.router)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleFrequentActionCurrencyExchangeRouter()
                }),
            app.on(blockchain.ux.frequent.action.swap)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleFrequentActionSwap()
                }),
            app.on(blockchain.ux.frequent.action.send)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleSendCrypto()
                }),
            app.on(blockchain.ux.frequent.action.rewards)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleRewards()
                }),
            app.on(blockchain.ux.frequent.action.deposit)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleDeposit()
                }),
            app.on(blockchain.ux.frequent.action.deposit.cash.identity.verification)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    showCashIdentityVerificationScreen()
                }),
            app.on(blockchain.ux.frequent.action.withdraw)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleWithdraw()
                }),
            app.on(blockchain.ux.frequent.action.nft)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [unowned self] _ in
                    handleNFTAssetView()
                })
        ]

        for observer in observers {
            observer.store(in: &bag)
        }
    }

    func subscribe(to viewStore: ViewStore<LoggedIn.State, LoggedIn.Action>) {
        displaySendCryptoScreen = viewStore.publisher
            .displaySendCryptoScreen
            .filter(\.self)
            .sink(to: My.handleSendCrypto, on: self)

        displayPostSignUpOnboardingFlow = viewStore.publisher
            .displayPostSignUpOnboardingFlow
            .filter(\.self)
            .delay(for: .seconds(4), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in
                // reset onboarding state
                viewStore.send(.didShowPostSignUpOnboardingFlow)
            })
            .sink(to: My.presentPostSignUpOnboarding, on: self)
    }
}

// not really intuitive tbh
func isSmallDevice() -> Bool {
    CGRect.screen.height < 812.0
}

// MARK: - Frame invalidation

// The following fixes SwiftUI's gesture handling that can get messed up when applying
// transforms and/or frame changes during an interactive presentation. This resets
// SwiftUI's geometry in a clean way, fixing hit testing.
// source: https://github.com/nathantannar4/Transmission/blob/main/Sources/Transmission/Sources/View/PresentationLinkAdapter.swift#L397-L399

private func invalidateFrames(controller: UIViewController?) {
    if let presentingFrame = controller?.presentedViewController?.view {
        invalidateFrame(of: presentingFrame)
    }
    if let fromFrame = controller?.view {
        invalidateFrame(of: fromFrame)
    }
}

private func invalidateFrame(of view: UIView) {
    let frame = view.frame
    view.frame = .zero
    view.frame = frame
}
