// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BigInt
import Combine
import DIKit
import EthereumKit
import FeatureTransactionDomain
import MoneyKit
import PlatformKit
import RxSwift
import RxToolKit
import ToolKit

final class ERC20OnChainTransactionEngine: OnChainTransactionEngine {

    // MARK: - OnChainTransactionEngine

    let currencyConversionService: CurrencyConversionServiceAPI
    let walletCurrencyService: FiatCurrencyServiceAPI

    var askForRefreshConfirmation: AskForRefreshConfirmation!
    var sourceAccount: BlockchainAccount!
    var transactionTarget: TransactionTarget!

    // MARK: - Private Properties

    private let ethereumOnChainEngineCompanion: EthereumOnChainEngineCompanionAPI
    private let receiveAddressFactory: ExternalAssetAddressServiceAPI
    private let erc20Token: AssetModel
    private let feeCache: CachedValue<EVMTransactionFee>
    private let feeService: EthereumKit.EthereumFeeServiceAPI
    private let transactionBuildingService: EthereumTransactionBuildingServiceAPI
    private let ethereumTransactionDispatcher: EthereumTransactionDispatcherAPI
    private let pendingTransactionRepository: PendingTransactionRepositoryAPI

    private lazy var cryptoCurrency = erc20Token.cryptoCurrency!

    private var erc20CryptoAccount: ERC20CryptoAccount {
        sourceAccount as! ERC20CryptoAccount
    }

    private var actionableBalance: Single<MoneyValue> {
        sourceAccount.actionableBalance.asSingle()
    }

    // MARK: - Init

    init(
        erc20Token: AssetModel,
        currencyConversionService: CurrencyConversionServiceAPI = resolve(),
        ethereumTransactionDispatcher: EthereumTransactionDispatcherAPI = resolve(),
        feeService: EthereumKit.EthereumFeeServiceAPI = resolve(),
        ethereumOnChainEngineCompanion: EthereumOnChainEngineCompanionAPI = resolve(),
        receiveAddressFactory: ExternalAssetAddressServiceAPI = resolve(),
        transactionBuildingService: EthereumTransactionBuildingServiceAPI = resolve(),
        pendingTransactionRepository: PendingTransactionRepositoryAPI = resolve(),
        walletCurrencyService: FiatCurrencyServiceAPI = resolve()
    ) {
        self.currencyConversionService = currencyConversionService
        self.erc20Token = erc20Token
        self.ethereumTransactionDispatcher = ethereumTransactionDispatcher
        self.feeService = feeService
        self.ethereumOnChainEngineCompanion = ethereumOnChainEngineCompanion
        self.receiveAddressFactory = receiveAddressFactory
        self.transactionBuildingService = transactionBuildingService
        self.pendingTransactionRepository = pendingTransactionRepository
        self.walletCurrencyService = walletCurrencyService

        self.feeCache = CachedValue(
            configuration: .onSubscription(
                schedulerIdentifier: "ERC20OnChainTransactionEngine"
            )
        )
        feeCache.setFetch(weak: self) { (self) -> Single<EVMTransactionFee> in
            self.feeService
                .fees(network: self.erc20CryptoAccount.network, cryptoCurrency: self.sourceCryptoCurrency)
                .asSingle()
        }
    }

    // MARK: - OnChainTransactionEngine

    func assertInputsValid() {
        defaultAssertInputsValid()
        precondition(sourceAccount is ERC20CryptoAccount)
        precondition(sourceCryptoCurrency.isERC20)
    }

    func initializeTransaction() -> Single<PendingTransaction> {
        sourceAccount.actionableBalance
            .zip(walletCurrencyService.displayCurrency.eraseError())
            .prefix(1)
            .map { [feeCryptoCurrency, cryptoCurrency, predefinedAmount] availableBalance, fiatCurrency -> PendingTransaction in
                let amount: MoneyValue = if let predefinedAmount,
                   predefinedAmount.currency == cryptoCurrency
                {
                    predefinedAmount
                } else {
                    .zero(currency: cryptoCurrency)
                }
                return PendingTransaction(
                    amount: amount,
                    available: availableBalance,
                    feeAmount: .zero(currency: feeCryptoCurrency),
                    feeForFullAvailable: .zero(currency: feeCryptoCurrency),
                    feeSelection: .init(
                        selectedLevel: .regular,
                        availableLevels: [.regular, .priority],
                        asset: feeCryptoCurrency
                    ),
                    selectedFiatCurrency: fiatCurrency
                )
            }
            .asSingle()
    }

    func doBuildConfirmations(
        pendingTransaction: PendingTransaction
    ) -> AnyPublisher<PendingTransaction, Error> {
        doBuildConfirmationsPublisher(pendingTransaction: pendingTransaction)
    }

    private func doBuildConfirmationsPublisher(
        pendingTransaction: PendingTransaction
    ) -> AnyPublisher<PendingTransaction, Error> {
        let fiatAmount = fiatAmount(from: pendingTransaction)
            .optional()
            .replaceError(with: nil)
            .eraseError()
        let fiatFeeAmount = fiatFeeAmount(from: pendingTransaction)
            .optional()
            .replaceError(with: nil)
            .eraseError()
        let feeOption = makeFeeSelectionOption(from: pendingTransaction)
        return Publishers
            .Zip3(fiatAmount, fiatFeeAmount, feeOption)
            .map { [weak self] fiatAmount, fiatFeeAmount, feeOption -> [TransactionConfirmation] in
                confirmations(
                    pendingTransaction: pendingTransaction,
                    sourceAccount: self?.sourceAccount,
                    transactionTarget: self?.transactionTarget,
                    fiatAmount: fiatAmount,
                    fiatFees: fiatFeeAmount,
                    feeOption: feeOption
                )
            }
            .prefix(1)
            .map { pendingTransaction.update(confirmations: $0) }
            .eraseToAnyPublisher()
    }

    func update(amount: MoneyValue, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        guard sourceAccount != nil else {
            return .just(pendingTransaction)
        }
        guard let crypto = amount.cryptoValue else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        guard crypto.currencyType == cryptoCurrency else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        return Single.zip(
            actionableBalance,
            absoluteFee(with: pendingTransaction.feeLevel)
        )
        .map { values -> PendingTransaction in
            let (actionableBalance, fee) = values
            return pendingTransaction.update(
                amount: amount,
                available: actionableBalance,
                fee: fee.moneyValue,
                feeForFullAvailable: fee.moneyValue
            )
        }
    }

    func doOptionUpdateRequest(
        pendingTransaction: PendingTransaction,
        newConfirmation: TransactionConfirmation
    ) -> Single<PendingTransaction> {
        if let feeSelection = newConfirmation as? TransactionConfirmations.FeeSelection,
           feeSelection.selectedLevel != pendingTransaction.feeLevel
        {
            updateFeeSelection(
                pendingTransaction: pendingTransaction,
                newFeeLevel: feeSelection.selectedLevel,
                customFeeAmount: nil
            )
        } else {
            defaultDoOptionUpdateRequest(
                pendingTransaction: pendingTransaction,
                newConfirmation: newConfirmation
            )
        }
    }

    func validateAmount(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateAmounts(pendingTransaction: pendingTransaction)
            .andThen(validateSufficientFunds(pendingTransaction: pendingTransaction))
            .andThen(validateSufficientGas(pendingTransaction: pendingTransaction))
            .updateTxValidityCompletable(pendingTransaction: pendingTransaction)
    }

    func doValidateAll(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateAmounts(pendingTransaction: pendingTransaction)
            .andThen(validateSufficientFunds(pendingTransaction: pendingTransaction))
            .andThen(validateSufficientGas(pendingTransaction: pendingTransaction))
            .andThen(validateNoPendingTransaction())
            .updateTxValidityCompletable(pendingTransaction: pendingTransaction)
    }

    func execute(pendingTransaction: PendingTransaction) -> Single<TransactionResult> {
        let erc20CryptoAccount = erc20CryptoAccount
        let erc20Token = erc20Token
        let network = erc20CryptoAccount.network
        let transactionBuildingService = transactionBuildingService
        let destinationAddresses = ethereumOnChainEngineCompanion
            .destinationAddresses(
                transactionTarget: transactionTarget,
                cryptoCurrency: sourceCryptoCurrency,
                receiveAddressFactory: receiveAddressFactory
            )
        let extraGasLimit = ethereumOnChainEngineCompanion
            .extraGasLimit(
                transactionTarget: transactionTarget,
                cryptoCurrency: sourceCryptoCurrency,
                receiveAddressFactory: receiveAddressFactory
            )
        return Single
            .zip(
                feeCache.valueSingle,
                destinationAddresses,
                extraGasLimit
            )
            .flatMap { fee, destinationAddresses, extraGasLimit
                -> Single<EthereumTransactionCandidate> in
                erc20CryptoAccount.nonce
                    .flatMap { nonce in
                        transactionBuildingService.buildTransaction(
                            amount: pendingTransaction.amount,
                            to: destinationAddresses.destination,
                            addressReference: destinationAddresses.referenceAddress,
                            gasPrice: fee.gasPrice(
                                feeLevel: pendingTransaction.feeLevel.ethereumFeeLevel
                            ),
                            gasLimit: fee.gasLimit(
                                extraGasLimit: extraGasLimit,
                                isContract: true
                            ),
                            nonce: nonce,
                            chainID: network.networkConfig.chainID,
                            contractAddress: erc20Token.contractAddress(network: network)
                        ).publisher
                    }
                    .asSingle()
            }
            .flatMap(weak: self) { (self, candidate) -> Single<EthereumTransactionPublished> in
                self.ethereumTransactionDispatcher.send(
                    transaction: candidate,
                    network: network.networkConfig
                )
                .asSingle()
            }
            .map(\.transactionHash)
            .map { transactionHash -> TransactionResult in
                .hashed(txHash: transactionHash, amount: pendingTransaction.amount)
            }
    }
}

extension ERC20OnChainTransactionEngine {

    private func validateNoPendingTransaction() -> Completable {
        pendingTransactionRepository
            .isWaitingOnTransaction(
                network: erc20CryptoAccount.network.networkConfig
            )
            .replaceError(with: true)
            .flatMap { isWaitingOnTransaction in
                isWaitingOnTransaction
                    ? AnyPublisher.failure(TransactionValidationFailure(state: .transactionInFlight))
                    : AnyPublisher.just(())
            }
            .asCompletable()
    }

    private func validateAmounts(pendingTransaction: PendingTransaction) -> Completable {
        Completable.fromCallable { [cryptoCurrency] in
            guard try pendingTransaction.amount > .zero(currency: cryptoCurrency) else {
                throw TransactionValidationFailure(state: .belowMinimumLimit(pendingTransaction.minSpendable))
            }
        }
    }

    private func validateSufficientFunds(pendingTransaction: PendingTransaction) -> Completable {
        guard sourceAccount != nil else {
            fatalError("sourceAccount should never be nil when this is called")
        }
        return actionableBalance
            .map { [sourceAccount, transactionTarget] actionableBalance -> Void in
                guard try pendingTransaction.amount <= actionableBalance else {
                    throw TransactionValidationFailure(
                        state: .insufficientFunds(
                            actionableBalance,
                            pendingTransaction.amount,
                            sourceAccount!.currencyType,
                            transactionTarget!.currencyType
                        )
                    )
                }
            }
            .asCompletable()
    }

    private func validateSufficientGas(pendingTransaction: PendingTransaction) -> Completable {
        Single
            .zip(
                ethereumAccountBalance.asSingle(),
                absoluteFee(with: pendingTransaction.feeLevel)
            )
            .map { balance, absoluteFee -> Void in
                guard try absoluteFee <= balance else {
                    throw TransactionValidationFailure(
                        state: .belowFees(absoluteFee.moneyValue, balance.moneyValue)
                    )
                }
            }
            .asCompletable()
    }

    private func makeFeeSelectionOption(
        from pendingTransaction: PendingTransaction
    ) -> AnyPublisher<TransactionConfirmations.FeeSelection, Error> {
        getFeeState(pendingTransaction: pendingTransaction)
            .map { feeState -> TransactionConfirmations.FeeSelection in
                TransactionConfirmations.FeeSelection(
                    feeState: feeState,
                    selectedLevel: pendingTransaction.feeLevel,
                    fee: pendingTransaction.feeAmount
                )
            }
            .eraseToAnyPublisher()
    }

    private func fiatAmount(
        from pendingTransaction: PendingTransaction
    ) -> AnyPublisher<FiatValue, PriceServiceError> {
        sourceExchangeRatePair
            .map { [cryptoCurrency] sourceExchange in
                let amount = pendingTransaction.amount.cryptoValue ?? .zero(currency: cryptoCurrency)
                let erc20Quote = sourceExchange.quote.fiatValue!
                let result = amount.convert(using: erc20Quote)
                return result
            }
            .eraseToAnyPublisher()
    }

    private func fiatFeeAmount(
        from pendingTransaction: PendingTransaction
    ) -> AnyPublisher<FiatValue, PriceServiceError> {
        feeExchangeRatePair
            .map { [cryptoCurrency] feeExchange in
                let feeAmount = pendingTransaction.feeAmount.cryptoValue ?? .zero(currency: cryptoCurrency)
                let feeQuote = feeExchange.quote.fiatValue!
                let result = feeAmount.convert(using: feeQuote)
                return result
            }
            .eraseToAnyPublisher()
    }

    /// Returns Ethereum CryptoValue of the maximum fee that the user may pay.
    private func absoluteFee(with feeLevel: FeeLevel) -> Single<CryptoValue> {
        feeCache.valueSingle
            .flatMap(weak: self) { (self, fees) -> Single<CryptoValue> in
                self.ethereumOnChainEngineCompanion
                    .absoluteFee(
                        feeLevel: feeLevel,
                        fees: fees,
                        transactionTarget: self.transactionTarget,
                        cryptoCurrency: self.sourceCryptoCurrency,
                        receiveAddressFactory: self.receiveAddressFactory,
                        isContract: true
                    )
            }
    }

    private var ethereumAccountBalance: AnyPublisher<CryptoValue, Error> {
        erc20CryptoAccount.nativeBalance
    }

    /// Streams `MoneyValuePair` for the exchange rate of the source ERC20 Asset in the current fiat currency.
    private var sourceExchangeRatePair: AnyPublisher<MoneyValuePair, PriceServiceError> {
        walletCurrencyService
            .displayCurrency
            .flatMap { [currencyConversionService, sourceAsset] fiatCurrency in
                currencyConversionService
                    .conversionRate(from: sourceAsset, to: fiatCurrency.currencyType)
                    .map { MoneyValuePair(base: .one(currency: sourceAsset), quote: $0) }
            }
            .eraseToAnyPublisher()
    }

    /// Streams `MoneyValuePair` for the exchange rate of Ethereum in the current fiat currency.
    private var feeExchangeRatePair: AnyPublisher<MoneyValuePair, PriceServiceError> {
        walletCurrencyService
            .displayCurrency
            .flatMap { [feeCryptoCurrency, currencyConversionService] fiatCurrency in
                currencyConversionService
                    .conversionRate(from: feeCryptoCurrency, to: fiatCurrency.currencyType)
                    .map { MoneyValuePair(base: .one(currency: feeCryptoCurrency), quote: $0) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private var feeCryptoCurrency: CurrencyType {
        erc20CryptoAccount.network.nativeAsset.currencyType
    }
}

private func confirmations(
    pendingTransaction: PendingTransaction,
    sourceAccount: BlockchainAccount?,
    transactionTarget: TransactionTarget?,
    fiatAmount: FiatValue?,
    fiatFees: FiatValue?,
    feeOption: TransactionConfirmations.FeeSelection
) -> [TransactionConfirmation] {
    let sourceLabel = sourceAccount?.label
    let targetLabel = transactionTarget?.label
    let feedTotal = TransactionConfirmations.FeedTotal(
        amount: pendingTransaction.amount,
        amountInFiat: fiatAmount?.moneyValue,
        fee: pendingTransaction.feeAmount,
        feeInFiat: fiatFees?.moneyValue
    )
    return [
        TransactionConfirmations.SendDestinationValue(value: pendingTransaction.amount),
        TransactionConfirmations.Source(value: sourceLabel ?? ""),
        TransactionConfirmations.Destination(value: targetLabel ?? ""),
        feeOption,
        feedTotal
    ]
}
