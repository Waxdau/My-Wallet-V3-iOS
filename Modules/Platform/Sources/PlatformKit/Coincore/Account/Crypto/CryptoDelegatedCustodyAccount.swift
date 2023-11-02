// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import Combine
import DelegatedSelfCustodyDomain
import Foundation
import MoneyKit
import ToolKit

public final class CryptoDelegatedCustodyAccount: CryptoNonCustodialAccount {

    public let asset: CryptoCurrency

    public let isDefault: Bool = true

    public lazy var identifier: String = "CryptoDelegatedCustodyAccount.\(asset.code)"

    public var receiveAddress: AnyPublisher<ReceiveAddress, Error> {
        addressesRepository
            .addresses(for: asset)
            .map { [publicKey] addresses in
                addresses
                    .first(where: { address in
                        address.publicKey == publicKey && address.isDefault
                    })
            }
            .onNil(ReceiveAddressError.notSupported)
            .flatMap { [addressFactory] match in
                addressFactory
                    .makeExternalAssetAddress(
                        address: match.address,
                        memo: nil,
                        label: match.address,
                        onTxCompleted: { _ in AnyPublisher.just(()) }
                    )
                    .publisher
                    .eraseError()
            }
            .map { $0 as ReceiveAddress }
            .eraseToAnyPublisher()
    }

    public var balance: AnyPublisher<MoneyValue, Error> {
        balanceRepository
            .balances
            .map { [asset] balances in
                balances.balance(index: 0, currency: asset) ?? MoneyValue.zero(currency: asset)
            }
            .eraseToAnyPublisher()
    }

    public var pendingBalance: AnyPublisher<MoneyValue, Error> {
        .just(.zero(currency: asset))
    }

    public var actionableBalance: AnyPublisher<MoneyValue, Error> {
        app.publisher(for: blockchain.app.configuration.dynamicselfcustody.static.fee, as: [String: String].self)
            .replaceError(with: [:])
            .setFailureType(to: Error.self)
            .combineLatest(balance)
            .tryMap { [asset] fees, balance throws -> MoneyValue in
                guard let minor = fees[asset.code] else { return balance }
                guard let fee = MoneyValue.create(minor: minor, currency: asset.currencyType) else { return balance }
                return try balance - fee
            }
            .eraseToAnyPublisher()
    }

    public var label: String {
        asset.defaultWalletName
    }

    public var assetName: String {
        asset.assetModel.name
    }

    public let accountType: AccountType = .nonCustodial
    public let delegatedCustodyAccount: DelegatedCustodyAccount

    private let app: AppProtocol
    private let addressesRepository: DelegatedCustodyAddressesRepositoryAPI
    private let addressFactory: ExternalAssetAddressFactory
    private let balanceRepository: DelegatedCustodyBalanceRepositoryAPI
    private let priceService: PriceServiceAPI

    private var publicKey: String {
        delegatedCustodyAccount.publicKey.hex
    }

    init(
        app: AppProtocol,
        addressesRepository: DelegatedCustodyAddressesRepositoryAPI,
        addressFactory: ExternalAssetAddressFactory,
        balanceRepository: DelegatedCustodyBalanceRepositoryAPI,
        priceService: PriceServiceAPI,
        delegatedCustodyAccount: DelegatedCustodyAccount
    ) {
        self.app = app
        self.addressesRepository = addressesRepository
        self.addressFactory = addressFactory
        self.balanceRepository = balanceRepository
        self.priceService = priceService
        self.delegatedCustodyAccount = delegatedCustodyAccount
        self.asset = delegatedCustodyAccount.coin
    }

    public func createTransactionEngine() -> Any {
        fatalError("DSC TransactionEngine constructor doesn't rely on this interface.")
    }

    public func can(perform action: AssetAction) -> AnyPublisher<Bool, Error> {
        switch action {
        case .buy,
             .deposit,
             .interestTransfer,
             .interestWithdraw,
             .stakingDeposit,
             .stakingWithdraw,
             .sign,
             .withdraw,
             .activeRewardsDeposit,
             .activeRewardsWithdraw:
            .just(false)
        case .send, .swap, .sell:
            balance
                .map(\.isPositive)
                .eraseToAnyPublisher()
        case .receive, .viewActivity:
            .just(true)
        }
    }

    public func balancePair(
        fiatCurrency: FiatCurrency,
        at time: PriceTime
    ) -> AnyPublisher<MoneyValuePair, Error> {
        balancePair(
            priceService: priceService,
            fiatCurrency: fiatCurrency,
            at: time
        )
    }

    public func mainBalanceToDisplayPair(
        fiatCurrency: FiatCurrency,
        at time: PriceTime
    ) -> AnyPublisher<MoneyValuePair, Error> {
        mainBalanceToDisplayPair(
            priceService: priceService,
            fiatCurrency: fiatCurrency,
            at: time
        )
    }

    public func invalidateAccountBalance() {}
}
