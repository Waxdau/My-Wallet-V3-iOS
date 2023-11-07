// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import Combine
import Foundation
import MoneyKit

public final class CoincoreNAPI {

    let app: AppProtocol
    let coincore: CoincoreAPI
    let currenciesService: EnabledCurrenciesServiceAPI

    public init(
        app: AppProtocol,
        coincore: CoincoreAPI,
        currenciesService: EnabledCurrenciesServiceAPI
    ) {
        self.app = app
        self.coincore = coincore
        self.currenciesService = currenciesService
    }

    public func register() async throws {

        var refresh = L_blockchain_namespace_napi_napi_policy.JSON()
        refresh.invalidate.on = [
            blockchain.ux.home.event.did.pull.to.refresh[],
            blockchain.ux.transaction.event.execution.status.completed[]
        ]

        func filter(
            _ filter: AssetFilter,
            predicate: ((SingleAccount) -> Bool)? = nil
        ) -> AnyPublisher<AnyJSON, Never> {
            coincore.allAccounts(filter: filter)
                .map { group in
                    let accountGroup: [SingleAccount] = if let predicate {
                        group.accounts.filter(predicate)
                    } else {
                        group.accounts
                    }
                    return AnyJSON(accountGroup.map(\.identifier))
                }
                .replaceError(with: .empty)
                .eraseToAnyPublisher()
        }

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.filter.accounts,
            repository: { tag in
                do {
                    return try filter(tag.context.decode(blockchain.coin.core.filter.id))
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.all,
            repository: { _ in filter(.all) }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.all,
            policy: refresh,
            repository: { _ in filter(.custodial) }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.DeFi.all.identifiers,
            repository: { [coincore, currenciesService] _ in
                coincore.allAccounts(filter: .nonCustodial)
                    .map(\.accounts)
                    .replaceError(with: [])
                    .flatMapLatest { (accounts: [SingleAccount]) -> AnyPublisher<AnyJSON, Never> in
                        let allERC20 = Set(currenciesService.allEnabledCryptoCurrencies.filter(\.isERC20))
                        let present: Set<CryptoCurrency> = Set(accounts.map(\.currencyType).compactMap(\.cryptoCurrency))
                        let missingERC20: Set<CryptoCurrency> = allERC20.subtracting(present)
                        let all = accounts.map { String(describing: $0.identifier) } + missingERC20.map(\.id)
                        return .just(AnyJSON(all))
                    }
                    .eraseToAnyPublisher()
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.DeFi.all.currencies,
            repository: { [coincore, currenciesService] _ in
                coincore.allAccounts(filter: .nonCustodial)
                    .map(\.accounts)
                    .replaceError(with: [])
                    .flatMapLatest { (accounts: [SingleAccount]) -> AnyPublisher<AnyJSON, Never> in
                        let allERC20 = Set(currenciesService.allEnabledCryptoCurrencies.filter(\.isERC20))
                        let present: Set<CryptoCurrency> = Set(accounts.map(\.currencyType).compactMap(\.cryptoCurrency))
                        let all = present.union(allERC20)
                        return .just(AnyJSON(all.map(\.code)))
                    }
                    .eraseToAnyPublisher()
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.interest.all,
            policy: refresh,
            repository: { _ in filter(.interest) }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.staking.all,
            policy: refresh,
            repository: { _ in filter(.staking) }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.active.rewards.all,
            policy: refresh,
            repository: { _ in filter(.activeRewards) }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.crypto.all.identifiers,
            policy: refresh,
            repository: { _ in
                filter(.custodial) { $0 is CryptoAccount }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.crypto.all.currencies,
            policy: refresh,
            repository: { [coincore] _ in
                coincore.allAccounts(filter: .custodial)
                    .map(\.accounts)
                    .replaceError(with: [])
                    .flatMapLatest { (accounts: [SingleAccount]) -> AnyPublisher<AnyJSON, Never> in
                        .just(AnyJSON(accounts.compactMap { $0.currencyType.cryptoCurrency?.code }))
                    }
                    .eraseToAnyPublisher()
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.fiat.all,
            policy: refresh,
            repository: { _ in
                filter(.custodial) { $0 is FiatAccount }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.fiat.with.balance,
            policy: refresh,
            repository: { [coincore] _ in
                coincore.accounts(filter: .custodial, where: \.currencyType.isFiatCurrency)
                    .replaceError(with: [])
                    .flatMap { accounts in
                        accounts.map { account in
                            account.balance.replaceError(with: .zero(currency: account.currencyType)).map { (account, $0) }
                        }.combineLatest()
                    }
                    .map { accounts in
                        AnyJSON(accounts.filter { _, money in money.isPositive }.map(\.0.identifier))
                    }
                    .eraseToAnyPublisher()
            }
        )

        func filter(
            _ filter: AssetFilter,
            _ currencyCode: AnyHashable?
        ) -> AnyPublisher<AnyJSON, Never> {
            coincore.accounts(filter: filter, where: { account in account.currencyType.code == (currencyCode as? String) })
                .replaceError(with: [])
                .map { accounts in AnyJSON(accounts.map(\.identifier)) }
                .eraseToAnyPublisher()
        }

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.asset,
            policy: refresh,
            repository: { tag in
                filter(.custodial, tag[blockchain.coin.core.accounts.custodial.asset.id])
                    .map { json in AnyJSON(json.array()?.first) } // custodial only have a single associated acount per asset
                    .eraseToAnyPublisher()
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.DeFi.asset,
            repository: { tag in
                filter(.nonCustodial, tag[blockchain.coin.core.accounts.DeFi.asset.id])
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.interest.asset,
            repository: { tag in
                filter(.interest, tag[blockchain.coin.core.accounts.interest.asset.id])
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.staking.asset,
            repository: { tag in
                filter(.staking, tag[blockchain.coin.core.accounts.staking.asset.id])
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.active.rewards.asset,
            repository: { tag in
                filter(.activeRewards, tag[blockchain.coin.core.accounts.active.rewards.asset.id])
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.custodial.crypto.with.balance,
            policy: refresh,
            repository: { [app, coincore] _ -> AnyPublisher<AnyJSON, Never> in
                coincore.allAccounts(filter: .custodial)
                    .combineLatest(
                        app.publisher(for: blockchain.user.currency.preferred.fiat.display.currency, as: FiatCurrency.self)
                            .compactMap(\.value)
                            .setFailureType(to: CoincoreError.self)
                    )
                    .map { group, fiatCurrency -> AnyPublisher<AnyJSON, Never> in
                        group.accounts
                            .filter { $0 is CryptoAccount }
                            .map { account -> AnyPublisher<(BlockchainAccount, MoneyValue), Never> in
                                account.balancePair(fiatCurrency: fiatCurrency)
                                    .map(\.quote)
                                    .replaceError(with: .zero(currency: fiatCurrency))
                                    .map { balance in (account, balance) }
                                    .eraseToAnyPublisher()
                            }
                            .combineLatest()
                            .map { each -> AnyJSON in
                                do {
                                    return try AnyJSON(
                                        each
                                            .filter { _, balance in balance.isPositive }
                                            .sorted { l, r in try l.1 > r.1 }
                                            .map(\.0.identifier)
                                    )
                                } catch {
                                    return .empty
                                }
                            }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
            }
        )

        var reloadDeFi = L_blockchain_namespace_napi_napi_policy.JSON()

        reloadDeFi.invalidate.on = [
            blockchain.app.coin.core.pkw.assets.loaded[],
            blockchain.ux.transaction.event.execution.status.completed[]
        ]

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.accounts.DeFi.with.balance,
            policy: reloadDeFi,
            repository: { [app, coincore] _ -> AnyPublisher<AnyJSON, Never> in
                coincore.allAccounts(filter: .nonCustodial)
                    .combineLatest(
                        app.publisher(for: blockchain.user.currency.preferred.fiat.display.currency, as: FiatCurrency.self)
                            .compactMap(\.value)
                            .setFailureType(to: CoincoreError.self)
                    )
                    .map { group, fiatCurrency -> AnyPublisher<AnyJSON, Never> in
                        typealias AccountData = (account: SingleAccount, isCryptoBalancePositive: Bool, fiatBalance: MoneyValue)
                        let publishers: [AnyPublisher<AccountData, Never>] = group.accounts
                            .map { account -> AnyPublisher<AccountData, Never> in
                                account.safeBalancePair(fiatCurrency: fiatCurrency)
                                    .map { balance, quote -> AccountData in
                                        let isPositive = balance?.isPositive ?? false
                                        let quote: MoneyValue = quote ?? .zero(currency: .fiat(fiatCurrency))
                                        return (account, isPositive, quote)
                                    }
                                    .eraseToAnyPublisher()
                            }
                        return publishers
                            .combineLatest()
                            .map { data -> AnyJSON in
                                var value = data
                                    .filter(\.isCryptoBalancePositive)
                                do {
                                    value = try value
                                        .sorted { l, r in try l.fiatBalance > r.fiatBalance }
                                } catch {}
                                return AnyJSON(value.map(\.account.identifier))
                            }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
            }
        )

        func account(_ tag: Tag.Reference) throws -> AnyPublisher<BlockchainAccount, Never> {
            // it is important to first check `coincore.account(_tag:)` and then fallback to `accountFromCurrency(_tag)`
            let identifier: String = try tag
                .context[blockchain.coin.core.account.id]
                .as(String.self)
                .or(throw: "No account id")
            return coincore.account(identifier)
                .tryMap { account -> AnyPublisher<BlockchainAccount, Never> in
                    guard let account else {
                        // if no account found on coincore.account(_ tag:)
                        // retrieve from asset from Coincore subscribe, if any
                        return try accountFromCurrency(tag)
                            .compacted()
                            .eraseToAnyPublisher()
                    }
                    return .just(account)
                }
                .ignoreFailure()
                .switchToLatest()
                .eraseToAnyPublisher()
        }

        func accountFromCurrency(_ tag: Tag.Reference) throws -> AnyPublisher<BlockchainAccount?, Never> {
            let identifier: String = try tag.context[blockchain.coin.core.account.id].or(throw: "No account id").decode()
            let currency = try CoincoreHelper
                .currency(from: identifier, service: currenciesService)
                .or(throw: "Unknown currency \(identifier)")
            let erc20Asset = try coincore[currency].or(throw: "Unknown asset \(currency)")
            return erc20Asset
                .defaultAccount
                .map { $0 as BlockchainAccount }
                .ignoreFailure(setFailureType: Never.self)
                .eraseToAnyPublisher()
        }

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account,
            repository: { [currenciesService] tag in
                do {
                    return try account(tag).map { account -> AnyJSON in
                        var json = L_blockchain_coin_core_account.JSON()
                        json.label = account.label
                        json.currency = account.currencyType.code
                        if let cryptoCurrency = account.currencyType.cryptoCurrency {
                            let evm = currenciesService.network(for: cryptoCurrency)
                            json.network.name = evm?.networkConfig.shortName
                            json.network.asset = evm?.nativeAsset.code
                        }
                        return json.toJSON()
                    }
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.balance.total,
            policy: refresh,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.balance.map { balance in AnyJSON(try? balance.encode().json()) }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.balance.pending,
            policy: refresh,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.pendingBalance.map { balance in AnyJSON(try? balance.encode().json()) }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.balance.available,
            policy: refresh,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.actionableBalance.map { balance in AnyJSON(try? balance.encode().json()) }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.is.funded,
            policy: refresh,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.isFunded.map { isFunded in AnyJSON(isFunded) }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.can.perform,
            policy: refresh,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.can(perform: .buy)
                            .combineLatest(
                                account.can(perform: .sell),
                                account.can(perform: .swap),
                                account.can(perform: .send)
                            ).map { buy, sell, swap, send -> AnyJSON in
                                var perform = L_blockchain_coin_core_account_can_perform.JSON()
                                perform.buy = buy
                                perform.sell = sell
                                perform.swap = swap
                                perform.send = send
                                return perform.toJSON()
                            }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )

        try await app.register(
            napi: blockchain.coin.core,
            domain: blockchain.coin.core.account.receive,
            repository: { tag in
                do {
                    return try account(tag).map { account -> AnyPublisher<AnyJSON, Error> in
                        account.receiveAddress
                            .combineLatest(account.firstReceiveAddress.optional().prepend(nil))
                            .map { receiveAddress, firstReceiveAddress -> AnyJSON in
                                var receive = L_blockchain_coin_core_account_receive.JSON()
                                receive.address = receiveAddress.address
                                receive.memo = receiveAddress.memo
                                receive.first.address = firstReceiveAddress?.address ?? receiveAddress.address
                                if let qrMetadataProvider = receiveAddress as? QRCodeMetadataProvider {
                                    receive.qr.metadata.content = qrMetadataProvider.qrCodeMetadata.content
                                    receive.qr.metadata.title = qrMetadataProvider.qrCodeMetadata.title
                                }
                                return receive.toJSON()
                            }
                            .eraseToAnyPublisher()
                    }
                    .switchToLatest()
                    .replaceError(with: .empty)
                    .eraseToAnyPublisher()
                } catch {
                    return .just(.empty)
                }
            }
        )
    }
}

public enum CoincoreHelper {

    public static func currency(
        from identifier: String,
        service: EnabledCurrenciesServiceAPI
    ) -> CryptoCurrency? {
        if let currency = CryptoCurrency(code: identifier, service: service) {
            return currency
        }
        let code: String? = if #available(iOS 16.0, *) {
            extractCode(from: identifier)
        } else {
            fallBackExtractCode(from: identifier)
        }
        guard let code else {
            return nil
        }
        return CryptoCurrency(code: code, service: service)
    }

    @available(iOS 16, *)
    static func extractCode(from identifier: String) -> String? {
        try? #/^\w+\.(?P<code>[a-zA-Z]+(?:\.[a-zA-Z]+)?)(?:\.\w+)*$/#
            .firstMatch(in: identifier)
            .flatMap { match in
                match.output.code.string
            }
    }

    static func fallBackExtractCode(from identifier: String) -> String? {
        let pattern = "^\\w+\\.(?<code>[a-zA-Z]+(?:\\.[a-zA-Z]+)?)(?:\\.\\w+)*$"
        do {
            let expression = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            if let match = expression.firstMatch(in: identifier, options: [], range: .init(location: 0, length: identifier.utf16.count)) {
                if let codeRange = Range(match.range(withName: "code")) {
                    return String(identifier[codeRange])
                } else {
                    return nil
                }
            } else {
                return nil
            }
        } catch {
            print(error)
            return nil
        }
    }
}
