// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ActivityUIKit
import AnalyticsKit
import DashboardUIKit
import DIKit
import NetworkKit
import PlatformKit
import PlatformUIKit
import RIBs
import RxSwift
import ToolKit
import TransactionKit
import TransactionUIKit

final class TabControllerManager: NSObject {

    // MARK: - Properties

    @objc let tabViewController: TabViewController

    // MARK: - Private Properties

    private var activityNavigationController: UINavigationController!
    private var dashboardNavigationController: UINavigationController!
    private var receiveNavigationViewController: UINavigationController!
    private var sendP2ViewController: UIViewController!
    private var swapViewController: UIViewController!
    private var swapRouter: ViewableRouting!
    private var sendRouter: SendRootRouting!

    private var analyticsEventRecorder: AnalyticsEventRecording
    private let receiveCoordinator: ReceiveCoordinator
    private let featureConfigurator: FeatureConfiguring
    private let internalFeatureFlag: InternalFeatureFlagServiceAPI
    private let coincore: Coincore
    private let disposeBag = DisposeBag()
    @LazyInject private var walletManager: WalletManager

    init(receiveCoordinator: ReceiveCoordinator = resolve(),
         analyticsEventRecorder: AnalyticsEventRecording = resolve(),
         featureConfigurator: FeatureConfiguring = resolve(),
         internalFeatureFlag: InternalFeatureFlagServiceAPI = resolve(),
         coincore: Coincore = resolve()) {
        self.analyticsEventRecorder = analyticsEventRecorder
        self.featureConfigurator = featureConfigurator
        self.internalFeatureFlag = internalFeatureFlag
        self.coincore = coincore
        self.receiveCoordinator = receiveCoordinator
        tabViewController = TabViewController.makeFromStoryboard()
        super.init()
        tabViewController.delegate = self
    }

    // MARK: - Show

    func showDashboard() {
        if dashboardNavigationController == nil {
            dashboardNavigationController = UINavigationController(rootViewController: DashboardViewController())
        }
        tabViewController.setActiveViewController(dashboardNavigationController,
                                                  animated: true,
                                                  index: Constants.Navigation.tabDashboard)
    }

    @objc func showTransactions() {
        if activityNavigationController == nil {
            activityNavigationController = UINavigationController(rootViewController: ActivityScreenViewController())
        }
        tabViewController.setActiveViewController(activityNavigationController,
                                                  animated: true,
                                                  index: Constants.Navigation.tabTransactions)
    }

    private func loadSwap() {
        guard swapViewController == nil else { return }
        guard swapRouter == nil else { return }

        func populateNewSwap() {
            let router = SwapRootBuilder().build()
            swapViewController = router.viewControllable.uiviewController
            swapRouter = router
            router.interactable.activate()
            router.load()
        }
        populateNewSwap()
    }

    func showSwap() {
        loadSwap()
        tabViewController.setActiveViewController(
            swapViewController,
            animated: true,
            index: Constants.Navigation.tabSwap
        )
    }

    private func loadSend() {
        guard sendP2ViewController == nil else { return }
        let router = SendRootBuilder().build()
        sendP2ViewController = router.viewControllable.uiviewController
        sendRouter = router
        router.interactable.activate()
        router.load()

    }
    private func setSendAsActive() {
        tabViewController.setActiveViewController(
            sendP2ViewController,
            animated: true,
            index: Constants.Navigation.tabSend
        )
    }

    func send(from account: BlockchainAccount) {
        loadSend()
        sendRouter.routeToSend(sourceAccount: account as! CryptoAccount)
    }

    func send(from account: BlockchainAccount, target: TransactionTarget) {
        loadSend()
        sendRouter.routeToSend(sourceAccount: account as! CryptoAccount, destination: target)
    }

    func showSend(cryptoCurrency: CryptoCurrency) {
        loadSend()
        setSendAsActive()
    }

    func showSend() {
        loadSend()
        setSendAsActive()
    }

    func showReceive() {
        if receiveNavigationViewController == nil {
            let receive = receiveCoordinator.builder.receive()
            receiveNavigationViewController = UINavigationController(rootViewController: receive)
        }
        tabViewController.setActiveViewController(receiveNavigationViewController,
                                                  animated: true,
                                                  index: Constants.Navigation.tabReceive)
    }

    // MARK: BitPay

    func setupBitpayPayment(from url: URL) {
        let data = url.absoluteString
        guard let asset = coincore[.bitcoin] else { return }
        let transactionPair = Single.zip(
            BitPayInvoiceTarget.make(from: data, asset: .bitcoin),
            asset.defaultAccount
        )
        BitPayInvoiceTarget
            .isBitPay(data)
            .andThen(BitPayInvoiceTarget.isBitcoin(data))
            .andThen(transactionPair)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] target, defaultAccount in
                UIView.animate(
                    withDuration: 0.3,
                    animations: { [weak self] in
                        self?.showSend()
                    },
                    completion: { [weak self] _ in
                        self?.send(from: defaultAccount, target: target)
                    }
                )
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - WalletTransactionDelegate

extension TabControllerManager: WalletTransactionDelegate {
    func onTransactionReceived() {
        SoundManager.shared.playBeep()
        NotificationCenter.default.post(Notification(name: Constants.NotificationKeys.transactionReceived))
    }
}

// MARK: - TabViewControllerDelegate

extension TabControllerManager: TabViewControllerDelegate {
    func tabViewController(_ tabViewController: TabViewController, viewDidAppear animated: Bool) {
        // NOOP
    }

    // MARK: - View Life Cycle

    func tabViewControllerViewDidLoad(_ tabViewController: TabViewController) {
        walletManager.transactionDelegate = self
    }

    func sendClicked() {
        showSend()
    }

    func receiveClicked() {
        showReceive()
    }

    func transactionsClicked() {
        analyticsEventRecorder.record(
             event: AnalyticsEvents.Transactions.transactionsTabItemClick
         )
        showTransactions()
    }

    func dashBoardClicked() {
        showDashboard()
    }

    func swapClicked() {
        analyticsEventRecorder.record(events: [
            AnalyticsEvents.Swap.swapTabItemClick,
            AnalyticsEvents.New.SimpleBuy.swapClicked
        ])
        showSwap()
    }
}
