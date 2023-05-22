// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import Combine
import FeatureAppDomain
import FeatureInterestUI
import FeatureOnboardingUI
import FeaturePin
import FeatureProductsDomain
import FeatureTransactionUI
import Localization
import MoneyKit
import PlatformKit
import PlatformUIKit
import SwiftUI
import ToolKit

public protocol SuperAppRootControllableLoggedInBridge: SuperAppRootControllable, LoggedInBridge {}

@available(iOS 15, *)
extension SuperAppRootController: SuperAppRootControllableLoggedInBridge {
    public func alert(_ content: AlertViewContent) {
        alertViewPresenter.notify(content: content, in: topMostViewController ?? self)
    }

    public func presentPostSignUpOnboarding() {
        onboardingRouter.presentPostSignUpOnboarding(from: topMostViewController ?? self)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { output in
                "\(output)".peek("🏄")
            })
            .sink { [weak self] result in
                guard let self, presentedViewController != nil, result == .completed else {
                    return
                }
                dismiss(animated: true)
            }
            .store(in: &bag)
    }

    public func toggleSideMenu() {
        topMostViewController?.dismiss(animated: true) { [app] in
            app.post(
                event: blockchain.ux.user.account,
                context: [blockchain.ui.type.action.then.enter.into.embed.in.navigation: false]
            )
        }
    }

    public func closeSideMenu() {
        app.post(event: blockchain.ui.type.action.then.close)
    }

    public func send(from account: BlockchainAccount) {
        transactionsRouter.presentTransactionFlow(to: .send(account, nil))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func send(from account: BlockchainAccount, target: TransactionTarget) {
        transactionsRouter.presentTransactionFlow(to: .send(account, target))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func sign(from account: BlockchainAccount, target: TransactionTarget) {
        transactionsRouter.presentTransactionFlow(
            to: .sign(
                sourceAccount: account,
                destination: target
            )
        )
        .sink { result in "\(result)".peek("🧾") }
        .store(in: &bag)
    }

    public func receive(into account: BlockchainAccount) {
        transactionsRouter.presentTransactionFlow(to: .receive(account as? CryptoAccount))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func withdraw(from account: BlockchainAccount) {
        guard let account = account as? FiatAccount else {
            return
        }
        transactionsRouter.presentTransactionFlow(to: .withdraw(account))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func deposit(into account: BlockchainAccount) {
        guard let account = account as? FiatAccount else {
            return
        }
        transactionsRouter.presentTransactionFlow(to: .deposit(account))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func interestTransfer(into account: BlockchainAccount) {
        guard let account = account as? CryptoInterestAccount else {
            return
        }
        transactionsRouter.presentTransactionFlow(to: .interestTransfer(account))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func interestWithdraw(from account: BlockchainAccount, target: TransactionTarget) {
        guard let account = account as? CryptoInterestAccount,
              let target = target as? CryptoTradingAccount
        else {
            return
        }
        transactionsRouter.presentTransactionFlow(to: .interestWithdraw(account, target))
            .sink { result in "\(result)".peek("🧾") }
            .store(in: &bag)
    }

    public func switchToSend() {
        handleSendCrypto()
    }

    public func switchTabToReceive() {
        handleReceiveCrypto()
    }

    public func switchToActivity() {
        Task {
            do {
                try await app.set(
                    blockchain.ux.user.activity.all.entry.paragraph.button.secondary.tap.then.enter.into,
                    to: blockchain.ux.user.activity.all
                )
                app.post(
                    event: blockchain.ux.user.activity.all.entry.paragraph.button.secondary.tap
                )
            } catch {
                app.post(error: error)
            }
        }
    }

    public func showCashIdentityVerificationScreen() {
        let topController = topMostViewController ?? self
        let router = SuperAppCashIdentityVerificationRouter(controller: topController)
        let presenter = CashIdentityVerificationPresenter(router: router)
        let controller = CashIdentityVerificationViewController(presenter: presenter); do {
            controller.transitioningDelegate = bottomSheetPresenter
            controller.modalPresentationStyle = .custom
            controller.isModalInPresentation = true
        }
        topController.present(controller, animated: true, completion: nil)
    }

    public func showFundTrasferDetails(fiatCurrency: FiatCurrency, isOriginDeposit: Bool) {

        if app.remoteConfiguration.result(for: blockchain.app.configuration.wire.transfer[fiatCurrency.code].is.enabled).value as? Bool == true {
            Task {
                app.state.set(blockchain.api.nabu.gateway.payments.accounts.simple.buy.id, to: fiatCurrency.code)
                app.post(
                    action: blockchain.ux.payment.method.wire.transfer.entry.paragraph.row.tap.then.enter.into,
                    value: blockchain.ux.payment.method.wire.transfer
                )
            }
            return
        }

        let interactor = InteractiveFundsTransferDetailsInteractor(
            fiatCurrency: fiatCurrency
        )

        let webViewRouter = WebViewRouter(
            topMostViewControllerProvider: self
        )

        Task {
            try await app.set(blockchain.ux.payment.method.wire.transfer.failed.then.navigate.to, to: blockchain.ux.error)
        }

        let presenter = FundsTransferDetailScreenPresenter(
            webViewRouter: webViewRouter,
            interactor: interactor,
            isOriginDeposit: isOriginDeposit,
            onError: { [app] error in
                app.post(event: blockchain.ux.payment.method.wire.transfer.failed, context: [blockchain.ux.error: error])
            }
        )

        let viewController = DetailsScreenViewController(presenter: presenter)
        let navigationController = UINavigationController(rootViewController: viewController)

        presenter.backRelay.publisher
            .sink { [weak navigationController] in
                navigationController?.dismiss(animated: true)
            }
            .store(in: &bag)

        topMostViewController?.present(navigationController, animated: true)
    }

    func handleFrequentActionCurrencyExchangeRouter() {
        Task {
            if await DexFeature.isEnabled(app: app) {
                try? await DexFeature.openCurrencyExchangeRouter(app: app)
            } else {
                handleSwapCrypto(account: nil)
            }
        }
    }

    func handleFrequentActionSwap() {
        handleSwapCrypto(account: nil)
    }

    public func handleSwapCrypto(account: CryptoAccount?) {
        let transactionsRouter = transactionsRouter
        let onboardingRouter = onboardingRouter
        coincore.hasPositiveDisplayableBalanceAccounts(for: .crypto)
            .prefix(1)
            .receive(on: DispatchQueue.main)
            .flatMap { positiveBalance -> AnyPublisher<TransactionFlowResult, Never> in
                if !positiveBalance {
                    guard let viewController = UIApplication.shared.topMostViewController else {
                        fatalError("Top most view controller cannot be nil")
                    }
                    return onboardingRouter
                        .presentRequiredCryptoBalanceView(from: viewController)
                        .map(TransactionFlowResult.init)
                        .eraseToAnyPublisher()
                } else {
                    return transactionsRouter.presentTransactionFlow(to: .swap(account))
                }
            }
            .sink { result in
                "\(result)".peek("🧾 \(#function)")
            }
            .store(in: &bag)
    }

    public func handleSendCrypto() {
        transactionsRouter.presentTransactionFlow(to: .send(nil, nil))
            .sink { result in
                "\(result)".peek("🧾 \(#function)")
            }
            .store(in: &bag)
    }

    public func handleReceiveCrypto() {
        transactionsRouter.presentTransactionFlow(to: .receive(nil))
            .sink { result in
                "\(result)".peek("🧾 \(#function)")
            }
            .store(in: &bag)
    }

    public func handleSellCrypto(account: CryptoAccount?) {
        transactionsRouter.presentTransactionFlow(to: .sell(account))
            .sink { result in
                "\(result)".peek("🧾 \(#function)")
            }
            .store(in: &bag)
    }

    public func handleBuyCrypto(account: CryptoAccount?) {
        transactionsRouter.presentTransactionFlow(to: .buy(account))
            .sink { result in
                "\(result)".peek("🧾 \(#function)")
            }
            .store(in: &bag)
    }

    public func handleBuyCrypto() {
        handleBuyCrypto(currency: .bitcoin)
    }

    public func handleBuyCrypto(currency: CryptoCurrency) {
        guard app.currentMode != .pkw else {
            showBuyCryptoOpenTradingAccount()
            return
        }

        coincore
            .cryptoAccounts(for: currency, supporting: .buy, filter: .custodial)
            .receive(on: DispatchQueue.main)
            .map(\.first)
            .sink(to: My.handleBuyCrypto(account:), on: self)
            .store(in: &bag)
    }

    private func currentFiatAccount() -> AnyPublisher<FiatAccount, CoincoreError> {
        fiatCurrencyService.tradingCurrencyPublisher
            .flatMap { [coincore] currency in
                coincore.allAccounts(filter: .allExcludingExchange)
                    .map { group in
                        group.accounts
                            .first { account in
                                account.currencyType.code == currency.code
                            }
                            .flatMap { account in
                                account as? FiatAccount
                            }
                    }
                    .first()
            }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    public func handleDeposit() {
        currentFiatAccount()
            .prefix(1)
            .sink(to: My.deposit(into:), on: self)
            .store(in: &bag)
    }

    public func handleWithdraw() {
        currentFiatAccount()
            .prefix(1)
            .sink(to: My.withdraw(from:), on: self)
            .store(in: &bag)
    }

    public func handleRewards() {
        let interestAccountList = InterestAccountListHostingController(embeddedInNavigationView: true)
        interestAccountList.delegate = self
        topMostViewController?.present(
            interestAccountList,
            animated: true
        )
    }

    public func handleNFTAssetView() {
        topMostViewController?.present(
            AssetListHostingViewController(),
            animated: true
        )
    }

    public func handleSupport() {
        let isSupported = app.publisher(for: blockchain.app.configuration.customer.support.is.enabled, as: Bool.self)
            .prefix(1)
            .replaceError(with: false)
        Publishers.Zip(
            isSupported,
            eligibilityService.isEligiblePublisher
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] isSupported, isEligible in
            guard let self else { return }
            guard isEligible, isSupported else {
                return showLegacySupportAlert()
            }
            showCustomerChatSupportIfSupported()
        })
        .store(in: &bag)
    }

    private func showCustomerChatSupportIfSupported() {
        tiersService
            .fetchTiers()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    switch completion {
                    case .failure(let error):
                        "\(error)".peek(as: .error, "‼️")
                        showLegacySupportAlert()
                    case .finished:
                        break
                    }
                },
                receiveValue: { [app] tiers in
                    guard tiers.isVerifiedApproved else {
                        self.showLegacySupportAlert()
                        return
                    }
                    self.presentedViewController?.dismiss(animated: true) {
                        app.post(event: blockchain.ux.customer.support.show.help.center)
                    }
                }
            )
            .store(in: &bag)
    }

    private func showLegacySupportAlert() {
        alert(
            .init(
                title: String(format: LocalizationConstants.openArg, Constants.Support.url),
                message: LocalizationConstants.youWillBeLeavingTheApp,
                actions: [
                    UIAlertAction(title: LocalizationConstants.continueString, style: .default) { _ in
                        guard let url = URL(string: Constants.Support.url) else { return }
                        UIApplication.shared.open(url)
                    },
                    UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
                ]
            )
        )
    }

    private func showBuyCryptoOpenTradingAccount() {
        let view = DefiBuyCryptoMessageView { [app] in
            app.state.set(blockchain.app.mode, to: AppMode.trading.rawValue)
        }
        let viewController = UIHostingController(rootView: view)
        viewController.transitioningDelegate = bottomSheetPresenter
        viewController.modalPresentationStyle = .custom
        present(viewController, animated: true, completion: nil)
    }

    public func startBackupFlow() {
        backupRouter.presentFlow()
    }

    public func showSettingsView() {
        app.post(
            action: blockchain.ux.user.account.entry.paragraph.button.icon.tap.then.enter.into,
            value: blockchain.ux.user.account,
            context: [blockchain.ui.type.action.then.enter.into.embed.in.navigation: false]
        )
    }

    public func reload() {}

    public func presentKYCIfNeeded() {
        topMostViewController?.dismiss(animated: true) { [self] in
            kycRouter
                .presentKYCIfNeeded(
                    from: topMostViewController ?? self,
                    requiredTier: .verified
                )
                .result()
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] result in
                    switch result {
                    case .success(let kycRoutingResult):
                        guard case .completed = kycRoutingResult else { return }
                        // Upon successful KYC completion, present Interest
                        self?.handleRewards()
                    case .failure(let kycRoutingError):
                        Logger.shared.error(kycRoutingError)
                    }
                })
                .store(in: &bag)
        }
    }

    public func presentBuyIfNeeded(_ cryptoCurrency: CryptoCurrency) {
        topMostViewController?.dismiss(animated: true) { [self] in
            handleBuyCrypto(currency: cryptoCurrency)
        }
    }

    public func enableBiometrics() {
        let logout = { [weak self] () -> Void in
            self?.global.send(.logout)
        }
        let flow = PinRouting.Flow.enableBiometrics(
            parent: UnretainedContentBox<UIViewController>(topMostViewController ?? self),
            logoutRouting: logout
        )
        pinRouter = PinRouter(flow: flow) { [weak self] input in
            guard let password = input.password else { return }
            self?.global.send(.wallet(.authenticateForBiometrics(password: password)))
            self?.pinRouter = nil
        }
        pinRouter?.execute()
    }

    public func changePin() {
        let logout = { [weak self] () -> Void in
            self?.global.send(.logout)
        }
        let flow = PinRouting.Flow.change(
            parent: UnretainedContentBox<UIViewController>(topMostViewController ?? self),
            logoutRouting: logout
        )
        pinRouter = PinRouter(flow: flow) { [weak self] _ in
            self?.pinRouter = nil
        }
        pinRouter?.execute()
    }

    public func showQRCodeScanner() {
        dismiss(animated: true) { [app] in
            app.post(
                action: blockchain.ux.user.account.entry.paragraph.button.icon.tap.then.enter.into,
                value: blockchain.ux.user.account,
                context: [blockchain.ui.type.action.then.enter.into.embed.in.navigation: false]
            )
        }
    }

    public func logout() {
        alert(
            .init(
                title: LocalizationConstants.SideMenu.logout,
                message: LocalizationConstants.SideMenu.logoutConfirm,
                actions: [
                    UIAlertAction(
                        title: LocalizationConstants.okString,
                        style: .default
                    ) { [weak self] _ in
                        self?.dismiss(animated: true)
                        self?.global.send(.logout)
                    },
                    UIAlertAction(
                        title: LocalizationConstants.cancel,
                        style: .cancel
                    )
                ]
            )
        )
    }

    public func logoutAndForgetWallet() {
        dismiss(animated: true)
        global.send(.deleteWallet)
    }

    public func handleSecureChannel() {
        app.post(event: blockchain.ui.type.action.then.close)
        app.post(
            action: blockchain.ux.scan.QR.entry.paragraph.button.primary.tap.then.enter.into,
            value: blockchain.ux.scan.QR,
            context: [blockchain.ui.type.action.then.enter.into.embed.in.navigation: false]
        )
    }
}
