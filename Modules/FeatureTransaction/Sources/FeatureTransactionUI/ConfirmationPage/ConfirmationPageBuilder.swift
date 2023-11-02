// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import Combine
import ComposableArchitecture
import DIKit
import Extensions
import FeatureCheckoutUI
import FeaturePlaidDomain
import FeatureTransactionDomain
import Localization
import MoneyKit
import PlatformKit
import PlatformUIKit
import RIBs
import SwiftUI
import UIKit

protocol ConfirmationPageListener: AnyObject {
    func closeFlow()
    func checkoutDidTapBack()
}

protocol ConfirmationPageBuildable {
    func build(listener: ConfirmationPageListener) -> ViewableRouter<Interactable, ViewControllable>
}

final class ConfirmationPageBuilder: ConfirmationPageBuildable {
    private let transactionModel: TransactionModel
    private let action: AssetAction
    private let app: AppProtocol
    private let priceService: PriceServiceAPI
    private let fiatCurrencyService: FiatCurrencyServiceAPI
    private let isNewCheckoutEnabled: Bool

    init(
        transactionModel: TransactionModel,
        action: AssetAction,
        priceService: PriceServiceAPI = resolve(),
        fiatCurrencyService: FiatCurrencyServiceAPI = resolve(),
        app: AppProtocol = DIKit.resolve(),
        isNewCheckoutEnabled: Bool
    ) {
        self.transactionModel = transactionModel
        self.action = action
        self.priceService = priceService
        self.fiatCurrencyService = fiatCurrencyService
        self.app = app
        self.isNewCheckoutEnabled = isNewCheckoutEnabled
    }

    func build(listener: ConfirmationPageListener) -> ViewableRouter<Interactable, ViewControllable> {
        if let newCheckout { return newCheckout }
        let detailsPresenter = ConfirmationPageDetailsPresenter()
        let viewController = DetailsScreenViewController(presenter: detailsPresenter)
        let interactor = ConfirmationPageInteractor(presenter: detailsPresenter, transactionModel: transactionModel)
        interactor.listener = listener
        return ConfirmationPageRouter(interactor: interactor, viewController: viewController)
    }

    var newCheckout: ViewableRouter<Interactable, ViewControllable>? {
        guard isNewCheckoutEnabled else { return nil }
        let viewController: UIViewController
        switch action {
        case .swap:
            viewController = buildSwapCheckout(for: transactionModel)
        case .buy:
            viewController = buildBuyCheckout(for: transactionModel)
        case .send:
            viewController = buildSendCheckout(for: transactionModel)
        case .sell:
            viewController = buildSellCheckout(for: transactionModel)
        case .deposit:
            viewController = buildDepositCheckout(for: transactionModel)
        case .withdraw:
            viewController = buildWithdrawCheckout(for: transactionModel)
        default:
            return nil
        }

        return ViewableRouter(
            interactor: Interactor(),
            viewController: viewController
        )
    }
}

// MARK: - Swap

extension ConfirmationPageBuilder {

    private func buildDepositCheckout(for transactionModel: TransactionModel) -> UIViewController {
        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .compactMap(\.depositCheckout)
            .removeDuplicates()

        let viewController = CheckoutHostingController(
            rootView: AsyncCheckoutView(
                publisher: publisher,
                checkout: { checkout in
                    DepositCheckoutView(
                        checkout: checkout,
                        confirm: { transactionModel.process(action: .executeTransaction) }
                    )
                }
            )
            .onAppear { transactionModel.process(action: .validateTransaction) }
                .navigationTitle(LocalizationConstants.Checkout.deposit)
                .navigationBarBackButtonHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: IconButton(
                        icon: .chevronLeft,
                        action: { [app] in
                            transactionModel.process(action: .returnToPreviousStep)
                            app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                        }
                    )
                )
                .app(app)
        )

        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        return viewController
    }

    private func buildWithdrawCheckout(for transactionModel: TransactionModel) -> UIViewController {
        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .compactMap(\.withdrawCheckout)
            .removeDuplicates()

        let viewController = CheckoutHostingController(
            rootView: AsyncCheckoutView(
                publisher: publisher,
                checkout: { checkout in
                    WithdrawCheckoutView(
                        checkout: checkout,
                        confirm: { transactionModel.process(action: .executeTransaction) }
                    )
                }
            )
            .onAppear { transactionModel.process(action: .validateTransaction) }
                .navigationTitle(LocalizationConstants.Checkout.withdraw)
                .navigationBarBackButtonHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: IconButton(
                        icon: .chevronLeft,
                        action: { [app] in
                            transactionModel.process(action: .returnToPreviousStep)
                            app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                        }
                    )
                )
                .app(app)
        )

        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        return viewController
    }

    private func buildSendCheckout(for transactionModel: TransactionModel) -> UIViewController {
        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .compactMap(\.sendCheckout)
            .removeDuplicates()

        let viewController = CheckoutHostingController(
            rootView: SendCheckoutView(publisher: publisher, confirm: { transactionModel.process(action: .executeTransaction) })
                .onAppear { transactionModel.process(action: .validateTransaction) }
                .navigationTitle(LocalizationConstants.Checkout.send)
                .navigationBarBackButtonHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: IconButton(
                        icon: .chevronLeft,
                        action: { [app] in
                            transactionModel.process(action: .returnToPreviousStep)
                            app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                        }
                    )
                )
                .app(app)
        )
        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        return viewController
    }

    private func buildSellCheckout(for transactionModel: TransactionModel) -> UIViewController {
        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .compactMap(\.sellCheckout)
            .task { sellCheckout in
                var checkout = sellCheckout

                do {
                    let currency: FiatCurrency = try await app.get(blockchain.user.currency.preferred.fiat.trading.currency)
                    guard let networkFeeCryptoCurrency = sellCheckout.networkFee?.currency.cryptoCurrency else {
                        return sellCheckout
                    }

                    let sourceFeeExchangeRate = try await priceService.price(of: networkFeeCryptoCurrency, in: currency)
                        .exchangeRatePair(networkFeeCryptoCurrency)
                        .await()

                    checkout.networkFeeExchangeRateToFiat = sourceFeeExchangeRate

                    return checkout
                } catch {
                    return checkout
                }
            }
            .removeDuplicates()

        let viewController = CheckoutHostingController(
            rootView: SellCheckoutView(
                publisher: publisher,
                confirm: { transactionModel.process(action: .executeTransaction) }
            )
            .onAppear { transactionModel.process(action: .validateTransaction) }
            .navigationTitle(LocalizationConstants.Checkout.sell)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: IconButton(
                    icon: .chevronLeft,
                    action: { [app] in
                        transactionModel.process(action: .returnToPreviousStep)
                        app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                    }
                )
            )
            .app(app)
        )
        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        return viewController
    }

    private func buildBuyCheckout(for transactionModel: TransactionModel) -> UIViewController {

        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .flatMap { [app] state -> AnyPublisher<(TransactionState, Bool), Never> in
                app.publisher(for: blockchain.ux.transaction.payment.method.is.available.for.recurring.buy, as: Bool.self)
                    .map(\.value)
                    .combineLatest(
                        app.publisher(for: blockchain.ux.transaction.action.select.recurring.buy.frequency, as: RecurringBuy.Frequency.self)
                            .map(\.value)
                    )
                    .map { isAvailable, frequency -> Bool in
                        let isAvailable = isAvailable ?? false
                        let frequency = frequency ?? .once
                        return isAvailable && frequency == .once
                    }
                    .map { (state, $0) }
                    .eraseToAnyPublisher()
            }
            .compactMap { state, displayInvestWeekly -> BuyCheckout? in
                state.provideBuyCheckout(shouldDisplayInvestWeekly: displayInvestWeekly)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()

        let viewController = CheckoutHostingController(
            rootView: BuyCheckoutView(publisher: publisher, confirm: { transactionModel.process(action: .executeTransaction) })
                .onAppear { transactionModel.process(action: .validateTransaction) }
                .navigationTitle(LocalizationConstants.Checkout.buyTitle)
                .navigationBarBackButtonHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: IconButton(
                        icon: .chevronLeft,
                        action: { [app] in
                            transactionModel.process(action: .returnToPreviousStep)
                            app.state.clear(blockchain.ux.transaction.checkout.recurring.buy.invest.weekly)
                            app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                        }
                    )
                )
                .app(app)
        )
        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        app.publisher(for: blockchain.ux.transaction["buy"].checkout.recurring.buy.invest.weekly, as: Bool.self)
            .map(\.value)
            .sink { value in
                guard let value else { return }
                let frequency: RecurringBuy.Frequency = value ? .weekly : .once
                transactionModel.process(action: .updateRecurringBuyFrequency(frequency))
            }
            .store(in: &viewController.bag)

        return viewController
    }

    private func buildSwapCheckout(for transactionModel: TransactionModel) -> UIViewController {

        let publisher = transactionModel.state.publisher
            .ignoreFailure(setFailureType: Never.self)
            .removeDuplicates(by: { old, new in old.pendingTransaction == new.pendingTransaction })
            .task { [app, priceService] state -> SwapCheckout? in
                guard var checkout = state.swapCheckout else { return nil }
                do {
                    let currency: FiatCurrency = try await app.get(blockchain.user.currency.preferred.fiat.trading.currency)

                    let sourceExchangeRate = try await priceService.price(of: checkout.from.cryptoValue.currency, in: currency)
                        .exchangeRatePair(checkout.from.cryptoValue.currency)
                        .await()

                    let sourceFeeExchangeRate = try await priceService.price(of: checkout.from.fee.currency, in: currency)
                        .exchangeRatePair(checkout.from.fee.currency)
                        .await()

                    let destinationExchangeRate = try await priceService.price(of: checkout.to.cryptoValue.currency, in: currency)
                        .exchangeRatePair(checkout.to.cryptoValue.currency)
                        .await()

                    checkout.from.exchangeRateToFiat = sourceExchangeRate
                    checkout.from.feeExchangeRateToFiat = sourceFeeExchangeRate

                    checkout.to.exchangeRateToFiat = destinationExchangeRate
                    checkout.to.feeExchangeRateToFiat = destinationExchangeRate

                    return checkout
                } catch {
                    return checkout
                }
            }
            .compactMap { $0 }

        let viewController = CheckoutHostingController(
            rootView: SwapCheckoutView(
                publisher: publisher.receive(on: DispatchQueue.main),
                confirm: { transactionModel.process(action: .executeTransaction) }
            )
            .onAppear { transactionModel.process(action: .validateTransaction) }
            .navigationTitle(LocalizationConstants.Checkout.swapTitle)
            .navigationBarBackButtonHidden(true)
            .whiteNavigationBarStyle()
            .navigationBarItems(
                leading: IconButton(
                    icon: .chevronLeft,
                    action: { [app] in
                        transactionModel.process(action: .returnToPreviousStep)
                        app.post(event: blockchain.ux.transaction.checkout.article.plain.navigation.bar.button.back)
                    }
                )
            )
            .app(app)
        )
        viewController.title = " "
        viewController.navigationItem.leftBarButtonItem = .init(customView: UIView())
        viewController.isModalInPresentation = true

        return viewController
    }
}

private class CheckoutHostingController<Content: View>: UIHostingController<Content> {
    var bag: Set<AnyCancellable> = []

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        bag.removeAll()
    }
}

extension Publisher where Output == PriceQuoteAtTime {

    func exchangeRatePair(_ currency: CryptoCurrency) -> AnyPublisher<MoneyValuePair, Failure> {
        map { MoneyValuePair(base: .one(currency: currency), exchangeRate: $0.moneyValue) }
            .eraseToAnyPublisher()
    }
}

extension PendingTransaction {
    var recurringBuyDetails: BuyCheckout.RecurringBuyDetails? {
        guard eligibleAndNextPaymentRecurringBuy != .oneTime else { return nil }
        return .init(
            frequency: eligibleAndNextPaymentRecurringBuy.frequency.description,
            description: eligibleAndNextPaymentRecurringBuy.date
        )
    }
}

extension Date {
    fileprivate static let in5Days = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
}

extension TransactionState {

    var depositCheckout: DepositCheckout? {
        guard let source, let destination, let pendingTransaction else { return nil }
        return DepositCheckout(
            from: source.label,
            to: destination.label,
            fee: pendingTransaction.feeAmount,
            settlementDate: .in5Days,
            availableToWithdraw: pendingTransaction.paymentsDepositTerms?.formattedAvailableToWithdraw,
            total: pendingTransaction.amount
        )
    }

    var withdrawCheckout: WithdrawCheckout? {
        guard let source, let destination, let pendingTransaction else { return nil }
        return WithdrawCheckout(
            from: source.label,
            to: destination.label,
            fee: pendingTransaction.feeAmount,
            settlementDate: .in5Days,
            total: pendingTransaction.amount
        )
    }

    var sellCheckout: SellCheckout? {
        guard let quote, let result = quote.result else { return nil }
        do {
            return try SellCheckout(
                value: result.base.cryptoValue.or(throw: "Not a crypto value"),
                quote: result.quote,
                networkFee: pendingTransaction?.feeAmount,
                networkFeeExchangeRateToFiat: nil,
                expiresAt: quote.date.expiresAt
            )
        } catch {
            return nil
        }
    }

    func provideBuyCheckout(shouldDisplayInvestWeekly: Bool) -> BuyCheckout? {
        guard let source, let quote, let result = quote.result else { return nil }
        do {
            let fee = quote.fee
            return try BuyCheckout(
                buyType: pendingTransaction?.recurringBuyFrequency == .once ? .simpleBuy : .recurringBuy,
                input: quote.amount,
                purchase: result,
                fee: fee.withoutPromotion.map {
                    try .init(value: $0.fiatValue.or(throw: "Buy fee is expected in fiat"), promotion: fee.value?.fiatValue)
                },
                exchangeRate: quote.exchangeRate.or(throw: "Expected exchange rate").fiatValue.or(throw: "Exchange Rate is expected in fiat"),
                total: quote.amount.fiatValue.or(throw: "Expected fiat"),
                paymentMethod: source.checkoutPaymentMethod(),
                quoteExpiration: quote.date.expiresAt,
                recurringBuyDetails: pendingTransaction?.recurringBuyDetails,
                depositTerms: .init(
                    availableToTrade: quote.depositTerms?.formattedAvailableToTrade,
                    availableToWithdraw: quote.depositTerms?.formattedAvailableToWithdraw,
                    withdrawalLockInDays: quote.depositTerms?.formattedWithdrawalLockDays
                ),
                displaysInvestWeekly: shouldDisplayInvestWeekly
            )
        } catch {
            return nil
        }
    }

    var sendCheckout: SendCheckout? {
        guard let pendingTransaction else { return nil }
        do {
            let source = try pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.Source.self).first.or(throw: "No source confirmation")
            let destination = try pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.Destination.self).first.or(throw: "No destination confirmation")

            let sourceTarget = SendCheckout.Target(
                name: source.value,
                isPrivateKey: self.source?.accountType == .nonCustodial
            )
            let destinationTarget = SendCheckout.Target(
                name: destination.value,
                isPrivateKey: self.destination?.accountType == .nonCustodial
            )

            var memo: SendCheckout.Memo?
            if let memoValue = pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.Memo.self).first
            {
                memo = SendCheckout.Memo(value: memoValue.value?.string)
            }

            let amountPair: SendCheckout.Amount

            // SendDestinationValue only appears on OnChainTransaction engines
            if pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.SendDestinationValue.self).first?.value != nil
            {
                let feeTotal = try pendingTransaction.confirmations.lazy
                    .filter(TransactionConfirmations.FeedTotal.self).first.or(throw: "No fee total confirmation")

                amountPair = SendCheckout.Amount(value: feeTotal.amount, fiatValue: feeTotal.amountInFiat)

                let feeLevel: FeeLevel = pendingTransaction.confirmations.lazy
                    .filter(TransactionConfirmations.FeeSelection.self)
                    .map(\.selectedLevel)
                    .first
                    .or(default: .regular)

                let checkoutFee = SendCheckout.Fee(
                    type: .network(level: feeLevel.title),
                    value: feeTotal.fee,
                    exchange: feeTotal.feeInFiat
                )
                let total: MoneyValue
                let totalFiat: MoneyValue?
                let totalPair: SendCheckout.Amount
                if feeTotal.amount.currency == feeTotal.fee.currency {
                    total = try feeTotal.amount + feeTotal.fee
                    if let amountInFiat = feeTotal.amountInFiat, let feeInFiat = feeTotal.feeInFiat {
                        totalFiat = try amountInFiat + feeInFiat
                    } else {
                        totalFiat = nil
                    }
                    totalPair = SendCheckout.Amount(value: total, fiatValue: totalFiat)
                } else {
                    total = feeTotal.amount
                    totalFiat = feeTotal.amountInFiat
                    totalPair = SendCheckout.Amount(value: total, fiatValue: totalFiat)
                }

                return SendCheckout(
                    amount: amountPair,
                    from: sourceTarget,
                    to: destinationTarget,
                    fee: checkoutFee,
                    total: totalPair,
                    memo: memo
                )
            }
            // Amount only appears on TradingToOnChain engine
            else if let amountEntry = pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.Amount.self).first
            {
                let fiatValue = amountEntry.exchange.map(MoneyValue.init(fiatValue:))
                amountPair = SendCheckout.Amount(value: amountEntry.amount, fiatValue: fiatValue)
                let processingFee = try pendingTransaction.confirmations.lazy
                    .filter(TransactionConfirmations.ProccessingFee.self).first.or(throw: "No processing fee confirmation")
                let fee = SendCheckout.Fee(type: .processing, value: processingFee.fee, exchange: processingFee.exchange)
                let totalValue = try pendingTransaction.confirmations.lazy
                    .filter(TransactionConfirmations.SendTotal.self).first.or(throw: "No total confirmation")
                let total = SendCheckout.Amount(value: totalValue.total, fiatValue: totalValue.exchange)
                return SendCheckout(
                    amount: amountPair,
                    from: sourceTarget,
                    to: destinationTarget,
                    fee: fee,
                    total: total,
                    memo: memo
                )
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    var swapCheckout: SwapCheckout? {
        guard let pendingTransaction else { return nil }
        guard
            let sourceValue = pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.SwapSourceValue.self).first?.cryptoValue,
            let destinationValue = pendingTransaction.confirmations.lazy
                .filter(TransactionConfirmations.SwapDestinationValue.self).first?.cryptoValue
        else { return nil }
        let sourceFee = pendingTransaction.confirmations.lazy
            .filter(TransactionConfirmations.NetworkFee.self)
            .first(where: \.feeType == .depositFee)?.primaryCurrencyFee.cryptoValue
        let destinationFee = pendingTransaction.confirmations.lazy
            .filter(TransactionConfirmations.NetworkFee.self)
            .first(where: \.feeType == .withdrawalFee)?.primaryCurrencyFee.cryptoValue

        let quoteExpiration = pendingTransaction.confirmations.lazy
            .filter(TransactionConfirmations.QuoteExpirationTimer.self).first?.expirationDate
        let sourceName = source?.accountType == .nonCustodial ? NonLocalizedConstants.defiWalletTitle : LocalizationConstants.Account.myTradingAccount
        let destinationName = destination?.accountType == .nonCustodial ? NonLocalizedConstants.defiWalletTitle : LocalizationConstants.Account.myTradingAccount

        return SwapCheckout(
            from: SwapCheckout.Target(
                name: sourceName,
                isPrivateKey: source?.accountType == .nonCustodial,
                cryptoValue: sourceValue,
                fee: sourceFee ?? .zero(currency: sourceValue.currency),
                exchangeRateToFiat: nil,
                feeExchangeRateToFiat: nil
            ),
            to: SwapCheckout.Target(
                name: destinationName,
                isPrivateKey: destination?.accountType == .nonCustodial,
                cryptoValue: destinationValue,
                fee: destinationFee ?? .zero(currency: destinationValue.currency),
                exchangeRateToFiat: nil,
                feeExchangeRateToFiat: nil
            ),
            quoteExpiration: quoteExpiration
        )
    }
}

extension BlockchainAccount {

    var isACH: Bool {
        (self as? PaymentMethodAccount)?.paymentMethod.type.isACH ?? false
    }

    func checkoutPaymentMethod() -> BuyCheckout.PaymentMethod {
        switch (self as? PaymentMethodAccount)?.paymentMethodType {
        case .card(let card):
            BuyCheckout.PaymentMethod(
                name: card.type.name,
                detail: card.displaySuffix,
                isApplePay: false,
                isACH: isACH
            )
        case .applePay(let apple):
            BuyCheckout.PaymentMethod(
                name: LocalizationConstants.Checkout.applePay,
                detail: apple.displaySuffix,
                isApplePay: true,
                isACH: isACH
            )
        case .account:
            BuyCheckout.PaymentMethod(
                name: LocalizationConstants.Checkout.funds,
                detail: nil,
                isApplePay: false,
                isACH: isACH
            )
        case .linkedBank(let bank):
            BuyCheckout.PaymentMethod(
                name: bank.account?.bankName ?? LocalizationConstants.Checkout.bank,
                detail: bank.account?.number,
                isApplePay: false,
                isACH: isACH
            )
        case .suggested(let suggestion):
            switch suggestion.type {
            case .applePay:
                BuyCheckout.PaymentMethod(
                    name: LocalizationConstants.Checkout.applePay,
                    detail: "••••",
                    isApplePay: true,
                    isACH: false
                )
            default:
                BuyCheckout.PaymentMethod(
                    name: label,
                    detail: nil,
                    isApplePay: false,
                    isACH: isACH
                )
            }
        default:
            BuyCheckout.PaymentMethod(
                name: label,
                detail: nil,
                isApplePay: false,
                isACH: isACH
            )
        }
    }
}
