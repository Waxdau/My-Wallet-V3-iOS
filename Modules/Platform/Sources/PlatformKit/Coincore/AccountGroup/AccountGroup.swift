// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import CombineExt
import RxSwift
import ToolKit

/// A `BlockchainAccount` that represents a collection of accounts, opposed to a single account.
public protocol AccountGroup: BlockchainAccount {
    var accounts: [SingleAccount] { get }

    func includes(account: BlockchainAccount) -> Bool

    var activityObservable: Observable<[ActivityItemEvent]> { get }
}

extension AccountGroup {
    /// An Observable stream that emits this AccountGroups accounts activity events.
    public var activityObservable: Observable<[ActivityItemEvent]> {
        Observable
            .combineLatest(
                accounts
                    .map(\.activity)
                    .map { $0.asObservable()
                        .startWith([])
                        .catchErrorJustReturn([])
                    }
            )
            .map { $0.flatMap { $0 } }
            .map { $0.unique.sorted(by: >) }
    }

    public var activity: Single<[ActivityItemEvent]> {
        Single
            .zip(accounts
                .map(\.activity)
                .map { $0.catchErrorJustReturn([]) })
            .map { $0.flatMap { $0 } }
            .map { $0.unique.sorted(by: >) }
    }

    public var currencyType: CurrencyType {
        guard let type = accounts.first?.currencyType else {
            fatalError("AccountGroup should have at least one account")
        }
        return type
    }

    public func fiatBalance(fiatCurrency: FiatCurrency, at time: PriceTime) -> AnyPublisher<MoneyValue, Error> {
        accounts
            .map { account in
                account.fiatBalance(fiatCurrency: fiatCurrency, at: time)
            }
            .zip()
            .tryMap { balances in
                try balances.reduce(MoneyValue.zero(currency: fiatCurrency), +)
            }
            .eraseToAnyPublisher()
    }

    public func balancePair(fiatCurrency: FiatCurrency, at time: PriceTime) -> AnyPublisher<MoneyValuePair, Error> {
        accounts
            .map { account in
                account.balancePair(fiatCurrency: fiatCurrency, at: time)
                    .replaceError(with: MoneyValuePair.zero(baseCurrency: account.currencyType, quoteCurrency: fiatCurrency.currency))
            }
            .zip()
            .tryMap { [currencyType] balancePairs in
                try balancePairs.reduce(.zero(baseCurrency: currencyType, quoteCurrency: fiatCurrency.currency), +)
            }
            .eraseToAnyPublisher()
    }

    public func includes(account: BlockchainAccount) -> Bool {
        accounts.map(\.identifier).contains(account.identifier)
    }

    public var actions: Single<AvailableActions> {
        Single.zip(accounts.map(\.actions))
            .map { actions -> AvailableActions in
                actions.reduce(into: AvailableActions()) { $0.formUnion($1) }
            }
    }

    public func can(perform action: AssetAction) -> Single<Bool> {
        Single
            .just(accounts.map { $0.can(perform: action) })
            .flatMapConcatFirst()
    }
}

public enum AccountGroupError: Error {
    case noBalance
    case noReceiveAddress
}

extension AnyPublisher where Output == [AccountGroup] {

    public func flatMapAllAccountGroup() -> AnyPublisher<AccountGroup, Failure> {
        map { groups in
            AllAccountsGroup(
                accounts: groups.map(\.accounts).flatMap { $0 }
            )
        }
        .eraseToAnyPublisher()
    }
}
