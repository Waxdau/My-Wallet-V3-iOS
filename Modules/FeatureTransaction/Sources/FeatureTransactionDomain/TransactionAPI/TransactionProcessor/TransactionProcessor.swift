// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import DIKit
import MoneyKit
import PlatformKit
import RxRelay
import RxSwift
import ToolKit

public final class TransactionProcessor {

    // MARK: - Public properties

    public var canTransactFiat: Bool {
        engine.canTransactFiat
    }

    public lazy var transactionExchangeRates: Observable<TransactionExchangeRates?> = pendingTxSubject
        .asObservable()
        .flatMap { [engine] pendingTransaction -> Observable<TransactionExchangeRates?> in
            engine.fetchExchangeRates(for: pendingTransaction)
                .optional()
                .replaceError(with: nil)
                .asObservable()
        }

    // Initialise the transaction as required.
    // This will start propagating the pendingTx to the client code.
    public var initializeTransaction: Observable<PendingTransaction> {
        engine
            .initializeTransaction()
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .asObservable()
            .flatMap(weak: self) { (self, _) -> Observable<PendingTransaction> in
                self.pendingTxSubject
            }
    }

    // MARK: - Private properties

    private let engine: TransactionEngine
    private let notificationCenter: NotificationCenter
    private let pendingTxSubject: BehaviorSubject<PendingTransaction>
    private let disposeBag = DisposeBag()

    // MARK: - Init

    init(
        sourceAccount: BlockchainAccount,
        transactionTarget: TransactionTarget,
        engine: TransactionEngine,
        notificationCenter: NotificationCenter = .default
    ) {
        self.engine = engine
        self.notificationCenter = notificationCenter
        self.pendingTxSubject = BehaviorSubject(value: .zero(currencyType: sourceAccount.currencyType))
        engine.start(
            sourceAccount: sourceAccount,
            transactionTarget: transactionTarget,
            askForRefreshConfirmation: { [weak self] revalidate in
                guard let self else {
                    return .empty()
                }
                return refreshConfirmations(revalidate: revalidate)
            }
        )
        engine.assertInputsValid()
    }

    // MARK: - Public methods

    public func reset() {
        do {
            try engine.stop(pendingTransaction: pendingTransaction())
        } catch {}
    }

    public func refresh() -> PendingTransaction? {
        do {
            let tx = try pendingTransaction()
            updatePendingTx(tx)
            return tx
        } catch {
            return nil
        }
    }

    // Set the option to the passed option value. If the option is not supported, it will not be
    // in the original list when the pendingTx is created. And if it is not supported, then trying to
    // update it will cause an error.
    public func set(transactionConfirmation: TransactionConfirmation) -> Completable {
        Logger.shared.debug("!TRANSACTION!> in `set(transactionConfirmation): \(transactionConfirmation)`")
        do {
            let pendingTx = try pendingTransaction()
            if !pendingTx.confirmations.contains(where: {
                String(describing: Swift.type(of: $0)) == String(describing: Swift.type(of: transactionConfirmation))
                && $0.type == transactionConfirmation.type
            }) {
                let error = PlatformKitError.illegalStateException(
                    message: "Unsupported TransactionConfirmation: \(transactionConfirmation)"
                )
                return .just(event: .error(error))
            }
            return engine
                .doOptionUpdateRequest(
                    pendingTransaction: pendingTx,
                    newConfirmation: transactionConfirmation
                )
                .flatMap(weak: self) { (self, transaction) -> Single<PendingTransaction> in
                    self.engine.doValidateAll(pendingTransaction: transaction)
                }
                .do(onSuccess: { [weak self] transaction in
                    guard let self else { return }
                    updatePendingTx(transaction)
                })
                .asObservable()
                .ignoreElements()
                .asCompletable()
        } catch {
          return .just(event: .error(error))
        }
    }

    public func updateQuote(_ quote: BrokerageQuote) -> Completable {
        do {
            let pendingTransaction = try pendingTransaction()
                .update(quote: quote)
            return engine.doBuildConfirmations(pendingTransaction: pendingTransaction)
                .handleEvents(receiveOutput: { [pendingTxSubject] pendingTransaction in
                    pendingTxSubject.on(.next(pendingTransaction))
                })
                .asCompletable()
        } catch {
            return .error(error)
        }
    }

    public func updatePrice(_ quote: BrokerageQuote.Price) -> Completable {
        do {
            if let swap = engine as? SwapTransactionEngine {
                return try swap.update(price: quote, on: pendingTransaction())
                    .asCompletable()
            } else if let sell = engine as? SellTransactionEngine {
                return try sell.update(price: quote, on: pendingTransaction())
                    .asCompletable()
            } else {
                return .just(event: .completed)
            }
        } catch {
            return .error(error)
        }
    }

    public func updateRecurringBuyFrequency(_ frequency: RecurringBuy.Frequency) -> Single<PendingTransaction> {
        .create(weak: self) { (self, fulfill) in
            do {
                let pendingTransaction = try self.pendingTransaction()
                self.updatePendingTx(pendingTransaction.updateRecurringBuyFrequency(frequency))
                fulfill(.success(pendingTransaction))
            } catch {
                fulfill(.error(error))
            }
            return Disposables.create()
        }
        .flatMap { [engine] pendingTx in
            engine.doValidateAll(pendingTransaction: pendingTx)
        }
    }

    private func validateFiatSupport(amount: MoneyValue) throws {
        if !canTransactFiat, amount.isFiat {
            throw PlatformKitError.illegalStateException(
                message: "Engine.canTransactFiat \(canTransactFiat) but amount.isFiat: \(amount.isFiat)"
            )
        }
    }

    public func updateAmount(amount: MoneyValue) -> Completable {
        Logger.shared.debug("!TRANSACTION!> in `updateAmount: \(amount.displayString)`")
        do {
            try validateFiatSupport(amount: amount)
        } catch {
            return .error(error)
        }

        let transaction: PendingTransaction
        do {
            transaction = try pendingTransaction()
        } catch {
            return .error(error)
        }

        return engine
            .update(amount: amount, pendingTransaction: transaction)
            .flatMap(weak: self) { (self, transaction) -> Single<PendingTransaction> in
                let isFreshTx = transaction.validationState.isUninitialized
                return self.engine
                    .validateAmount(pendingTransaction: transaction)
                    .map { transaction -> PendingTransaction in
                        var transaction = transaction
                        // Remove initial "insufficient funds" warning.
                        if isFreshTx,
                           transaction.amount.isZero,
                           !transaction.validationState.isCanExecute
                        {
                            transaction.validationState = .uninitialized
                        }
                        return transaction
                    }
            }
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .asCompletable()
    }

    public func createOrder() -> Single<TransactionOrder?> {
        do {
            return try engine.createOrder(pendingTransaction: pendingTransaction())
        } catch {
            return .error(error)
        }
    }

    public func cancelOrder(with identifier: String) -> Single<Void> {
        engine.cancelOrder(with: identifier)
    }

    public func execute(order: TransactionOrder?) -> Single<TransactionResult> {
        Logger.shared.debug("!TRANSACTION!> in `execute`")
        let pendingTransaction: PendingTransaction
        do {
            pendingTransaction = try self.pendingTransaction()
        } catch {
            return .error(error)
        }

        return engine
            .doValidateAll(pendingTransaction: pendingTransaction)
            .map { validatedTransaction in
                guard validatedTransaction.validationState == .canExecute else {
                    throw PlatformKitError.illegalStateException(message: "PendingTx is not executable because of \(validatedTransaction.validationState)")
                }
                return validatedTransaction
            }
            .flatMap { [engine] transaction in
                engine.execute(
                    pendingTransaction: transaction,
                    pendingOrder: order
                )
            }
            .flatMap { [engine] transactionResult -> Single<TransactionResult> in
                engine
                    .doPostExecute(transactionResult: transactionResult)
                    .replaceOutput(with: transactionResult)
                    .replaceError(with: transactionResult)
                    .replaceEmpty(with: transactionResult)
                    .asSingle()
            }
            .do(
                onSuccess: { [notificationCenter] _ in
                    notificationCenter.post(
                        name: .transaction,
                        object: nil
                    )
                }
            )
    }

    public func validateAll() -> Completable {
        Logger.shared.debug("!TRANSACTION!> in `validateAll`")
        guard let pendingTransaction = try? pendingTransaction() else {
            preconditionFailure("We should always have a pending transaction when validating")
        }
        return validateAll(pendingTransaction: pendingTransaction)
    }

    public func validateAll(pendingTransaction: PendingTransaction) -> Completable {
        Logger.shared.debug("!TRANSACTION!> in `validateAll`")
        return engine.doBuildConfirmations(pendingTransaction: pendingTransaction)
            .asSingle()
            .flatMap(weak: self) { (self, pendingTransaction) -> Single<PendingTransaction> in
                self.engine.doValidateAll(pendingTransaction: pendingTransaction)
            }
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .flatMap(weak: self) { (self, pendingTransaction) -> Single<PendingTransaction> in
                self.engine.startConfirmationsUpdate(pendingTransaction: pendingTransaction)
            }
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .asCompletable()
    }

    /// Check that the fee level is supported,
    /// then call into the engine to set the fee and validate ballances etc
    public func updateFeeLevel(_ feeLevel: FeeLevel, customFeeAmount: MoneyValue?) -> Completable {
        Logger.shared.debug("!TRANSACTION!> in `UpdateFeeLevel`")
        guard let pendingTransaction = try? pendingTransaction() else {
            preconditionFailure("We should always have a pending transaction when validating")
        }
        precondition(pendingTransaction.feeSelection.availableLevels.contains(feeLevel))
        return engine
            .doUpdateFeeLevel(
                pendingTransaction: pendingTransaction,
                level: feeLevel,
                customFeeAmount: customFeeAmount ?? .zero(currency: pendingTransaction.amount.currency)
            )
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .asCompletable()
    }

    // MARK: - Private methods

    /// Called back by the engine if it has received an external signal and the existing confirmation set
    /// requires a refresh
    private func refreshConfirmations(revalidate: Bool) -> Observable<Void> {
        Logger.shared.debug("!TRANSACTION!> in `refreshConfirmations`")
        guard let pendingTransaction = try? pendingTransaction() else {
            return .empty()
        }
        guard !pendingTransaction.confirmations.isEmpty else {
            return .empty()
        }
        return engine.doRefreshConfirmations(pendingTransaction: pendingTransaction)
            .asSingle()
            .flatMap { [engine] pendingTransaction -> Single<PendingTransaction> in
                if revalidate {
                    return engine.doValidateAll(pendingTransaction: pendingTransaction)
                }
                return .just(pendingTransaction)
            }
            .do(onSuccess: { [weak self] pendingTransaction in
                self?.updatePendingTx(pendingTransaction)
            })
            .mapToVoid()
            .asObservable()
    }

    private func pendingTransaction() throws -> PendingTransaction {
        try pendingTxSubject.value()
    }

    private func updatePendingTx(_ transaction: PendingTransaction) {
        pendingTxSubject.on(.next(transaction))
    }
}
