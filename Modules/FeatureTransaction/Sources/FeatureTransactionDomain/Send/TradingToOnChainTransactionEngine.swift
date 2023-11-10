// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import DIKit
import MoneyKit
import PlatformKit
import RxSwift
import RxToolKit
import ToolKit

final class TradingToOnChainTransactionEngine: TransactionEngine {

    let walletCurrencyService: FiatCurrencyServiceAPI
    let currencyConversionService: CurrencyConversionServiceAPI
    var askForRefreshConfirmation: AskForRefreshConfirmation!
    var sourceAccount: BlockchainAccount!
    var transactionTarget: TransactionTarget!

    var sourceTradingAccount: CryptoTradingAccount! {
        sourceAccount as? CryptoTradingAccount
    }

    var target: CryptoReceiveAddress {
        transactionTarget as! CryptoReceiveAddress
    }

    var targetAsset: CryptoCurrency { target.asset }

    // MARK: - Private Properties

    private let transferRepository: CustodialTransferRepositoryAPI
    private let transactionLimitsService: TransactionLimitsServiceAPI

    // MARK: - Init

    init(
        walletCurrencyService: FiatCurrencyServiceAPI = resolve(),
        currencyConversionService: CurrencyConversionServiceAPI = resolve(),
        transferRepository: CustodialTransferRepositoryAPI = resolve(),
        transactionLimitsService: TransactionLimitsServiceAPI = resolve()
    ) {
        self.walletCurrencyService = walletCurrencyService
        self.currencyConversionService = currencyConversionService
        self.transferRepository = transferRepository
        self.transactionLimitsService = transactionLimitsService
    }

    func assertInputsValid() {
        precondition(transactionTarget is CryptoReceiveAddress)
        precondition(sourceAsset == targetAsset)
    }

    func initializeTransaction() -> Single<PendingTransaction> {
        let transactionLimits = transactionLimitsService
            .fetchLimits(
                source: LimitsAccount(
                    currency: sourceAccount.currencyType,
                    accountType: .custodial
                ),
                destination: LimitsAccount(
                    currency: targetAsset.currencyType,
                    accountType: .nonCustodial // even exchange accounts are considered non-custodial atm.
                )
            )

        let sourceAccountCurrencyType = sourceAccount.currencyType
        let withdrawalMaxFees = walletCurrencyService.tradingCurrencyPublisher
            .flatMap { [transferRepository] userFiat -> AnyPublisher<WithdrawalFees, Error> in
                transferRepository.withdrawalFees(
                    currency: sourceAccountCurrencyType,
                    fiatCurrency: userFiat.currencyType,
                    amount: "0",
                    max: true
                )
                .eraseError()
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()

        return transactionLimits.eraseError()
            .zip(
                walletCurrencyService.tradingCurrencyPublisher.eraseError(),
                withdrawalMaxFees,
                sourceTradingAccount.withdrawableBalance
            )
            .tryMap { [sourceAsset, predefinedAmount] transactionLimits, walletCurrency, maxFees, withdrawableBalance
                -> PendingTransaction in
                let amount: MoneyValue = if let predefinedAmount,
                   predefinedAmount.currencyType == sourceAsset
                {
                    predefinedAmount
                } else {
                    .zero(currency: sourceAsset)
                }
                let maxFee = maxFees.totalFees.amount.value
                let available = try withdrawableBalance - maxFee
                let pendingTransaction = PendingTransaction(
                    amount: amount,
                    available: available.isNegative ? .zero(currency: sourceAsset) : available,
                    feeAmount: maxFee,
                    feeForFullAvailable: maxFee,
                    feeSelection: .empty(asset: sourceAsset),
                    selectedFiatCurrency: walletCurrency,
                    limits: transactionLimits.update(minimum: maxFees.minAmount.amount.value)
                )
                return pendingTransaction
            }
            .asSingle()
    }

    func update(amount: MoneyValue, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        guard sourceTradingAccount != nil else {
            return .just(pendingTransaction)
        }
        // because of the dynamic nature of the withdrawal fees,
        // we don't want to request the fee api when the user enters or taps on send max
        // instead we use the max fees we calculated at initialization
        if amount.isPositive, amount == pendingTransaction.available {
            return .just(
                pendingTransaction
                    .update(amount: amount)
                    .update(fee: pendingTransaction.feeForFullAvailable)
            )
        } else {
            let withdrawalFees = walletCurrencyService.tradingCurrencyPublisher
                .flatMap { [transferRepository] userFiat -> AnyPublisher<WithdrawalFees, Error> in
                    transferRepository.withdrawalFees(
                        currency: amount.currencyType,
                        fiatCurrency: userFiat.currencyType,
                        amount: amount.minorString,
                        max: false
                    )
                    .eraseError()
                    .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()

            return withdrawalFees
                .map { fees -> PendingTransaction in
                    var pendingTransaction = pendingTransaction.update(
                        amount: amount,
                        available: pendingTransaction.available,
                        fee: fees.totalFees.amount.value,
                        feeForFullAvailable: pendingTransaction.feeForFullAvailable
                    )
                    let transactionLimits = pendingTransaction.limits ?? .noLimits(for: amount.currency)
                    pendingTransaction.limits = TransactionLimits(
                        currencyType: transactionLimits.currencyType,
                        minimum: fees.minAmount.amount.value,
                        maximum: transactionLimits.maximum,
                        maximumDaily: transactionLimits.maximumDaily,
                        maximumAnnual: transactionLimits.maximumAnnual,
                        effectiveLimit: transactionLimits.effectiveLimit,
                        suggestedUpgrade: transactionLimits.suggestedUpgrade,
                        earn: transactionLimits.earn
                    )
                    return pendingTransaction
                }
                .eraseError()
                .asSingle()
        }
    }

    func doBuildConfirmations(
        pendingTransaction: PendingTransaction
    ) -> AnyPublisher<PendingTransaction, Error> {
        convertAmountIntoTradingCurrency(pendingTransaction.amount)
            .zip(convertAmountIntoTradingCurrency(pendingTransaction.feeAmount))
            .tryMap { [sourceTradingAccount, target] fiatAmount, fiatFees -> [TransactionConfirmation] in
                let totalPlusFee = try pendingTransaction.amount + pendingTransaction.feeAmount
                let totalPlusFeeFiat = try fiatAmount.moneyValue + fiatFees.moneyValue
                var confirmations: [TransactionConfirmation] = [
                    TransactionConfirmations.Amount(amount: pendingTransaction.amount, exchange: fiatAmount),
                    TransactionConfirmations.Source(value: sourceTradingAccount!.label),
                    TransactionConfirmations.Destination(value: target.label),
                    TransactionConfirmations.ProccessingFee(
                        fee: pendingTransaction.feeAmount,
                        exchange: fiatFees.moneyValue
                    ),
                    TransactionConfirmations.SendTotal(
                        total: totalPlusFee,
                        exchange: totalPlusFeeFiat
                    )
                ]
                if TransactionMemoSupport.supportsMemo(sourceTradingAccount!.currencyType) {
                    confirmations.append(TransactionConfirmations.Memo(textMemo: target.memo))
                }
                return confirmations
            }
            .map { confirmations in
                pendingTransaction.update(confirmations: confirmations)
            }
            .eraseToAnyPublisher()
    }

    func validateAmount(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        defaultValidateAmount(pendingTransaction: pendingTransaction).asSingle()
    }

    func doValidateAll(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateAmount(pendingTransaction: pendingTransaction)
    }

    func execute(pendingTransaction: PendingTransaction) -> Single<TransactionResult> {
        transferRepository
            .transfer(
                moneyValue: pendingTransaction.amount,
                destination: target.address,
                fee: pendingTransaction.feeAmount,
                memo: target.memo
            )
            .map { identifier in
                TransactionResult.hashed(txHash: identifier, amount: pendingTransaction.amount)
            }
            .asSingle()
    }

    func doUpdateFeeLevel(
        pendingTransaction: PendingTransaction,
        level: FeeLevel,
        customFeeAmount: MoneyValue
    ) -> Single<PendingTransaction> {
        .just(pendingTransaction)
    }

    // MARK: - Private Functions

    private func convertAmountIntoTradingCurrency(_ amount: MoneyValue) -> AnyPublisher<FiatValue, Error> {
        guard amount.isFiat.isNo else {
            return .just(amount.fiatValue!)
        }
        return sourceExchangeRatePair
            .map { pair -> TransactionMoneyValuePairs in
                TransactionMoneyValuePairs(
                    source: pair,
                    destination: pair
                )
            }
            .tryMap { moneyPair in
                try amount
                    .convert(using: moneyPair.source)
                    .displayableRounding(roundingMode: .bankers)
                    .fiatValue!
            }
            .prefix(1)
            .eraseToAnyPublisher()
    }

    private var sourceExchangeRatePair: AnyPublisher<MoneyValuePair, Error> {
        let cryptoCurrency = transactionTarget.currencyType
        return walletCurrencyService
            .tradingCurrencyPublisher
            .map(\.currencyType)
            .flatMap { [currencyConversionService] tradingCurrency in
                currencyConversionService
                    .conversionRate(from: cryptoCurrency, to: tradingCurrency)
                    .map { quote in
                        MoneyValuePair(
                            base: .one(currency: cryptoCurrency),
                            quote: quote
                        )
                    }
            }
            .eraseError()
            .eraseToAnyPublisher()
    }
}

extension TransactionLimits {
    func update(minimum: MoneyValue) -> TransactionLimits {
        TransactionLimits(
            currencyType: minimum.currencyType,
            minimum: minimum,
            maximum: maximum,
            maximumDaily: maximumDaily,
            maximumAnnual: maximumAnnual,
            effectiveLimit: effectiveLimit,
            suggestedUpgrade: suggestedUpgrade,
            earn: nil
        )
    }
}
