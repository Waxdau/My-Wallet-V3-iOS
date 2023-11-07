// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BitcoinChainKit
import Combine
import DIKit
import PlatformKit
import ToolKit
import WalletPayloadKit

public enum BitcoinWalletRepositoryError: Error {
    case missingWallet
    case unableToRetrieveNote
    case failedToFetchAccount(Error)
}

final class BitcoinWalletAccountRepository {

    private struct Key: Hashable {}

    struct BTCAccounts: Equatable {
        let defaultAccount: BitcoinWalletAccount
        let accounts: [BitcoinWalletAccount]
    }

    // MARK: - Properties

    let defaultAccount: AnyPublisher<BitcoinWalletAccount, BitcoinWalletRepositoryError>
    /// All accounts, Defi Wallet and imported addresses (if any)
    let accounts: AnyPublisher<[BitcoinWalletAccount], BitcoinWalletRepositoryError>

    /// Any active accounts, excluding imported addresses
    let activeAccounts: AnyPublisher<[BitcoinWalletAccount], BitcoinWalletRepositoryError>
    let importedAccounts: AnyPublisher<[BitcoinWalletAccount], BitcoinWalletRepositoryError>

    private let cachedValue: CachedValueNew<
        Key,
        BTCAccounts,
        BitcoinWalletRepositoryError
    >
    private let bitcoinEntryFetcher: BitcoinEntryFetcherAPI
    private let accountNamingReplenishement: AccountNamingReplenishementAPI

    // MARK: - Init

    init(
        bitcoinEntryFetcher: BitcoinEntryFetcherAPI = resolve(),
        accountNamingReplenishement: AccountNamingReplenishementAPI = resolve()
    ) {
        self.bitcoinEntryFetcher = bitcoinEntryFetcher
        self.accountNamingReplenishement = accountNamingReplenishement

        let cache: AnyCache<Key, BTCAccounts> = InMemoryCache(
            configuration: .onLoginLogout(),
            refreshControl: PerpetualCacheRefreshControl()
        ).eraseToAnyCache()

        self.cachedValue = CachedValueNew(
            cache: cache,
            fetch: { _ in
                bitcoinEntryFetcher.fetchOrCreateBitcoin()
                    .mapError { _ in .missingWallet }
                    .map { entry in
                        let defaultIndex = entry.defaultAccountIndex
                        let defaultAccount = btcWalletAccount(from: entry.accounts[defaultIndex])
                        let accounts = entry.accounts.map(btcWalletAccount(from:)) + entry.importedAddresses.map(btcWalletAccount(from:))
                        return BTCAccounts(defaultAccount: defaultAccount, accounts: accounts)
                    }
                    .eraseToAnyPublisher()
            }
        )

        self.defaultAccount = cachedValue.get(key: Key())
            .map(\.defaultAccount)
            .eraseToAnyPublisher()

        self.accounts = cachedValue.get(key: Key())
            .map(\.accounts)
            .eraseToAnyPublisher()

        self.activeAccounts = accounts
            .map { accounts in
                accounts.filter { $0.isActive && !$0.imported }
            }
            .eraseToAnyPublisher()

        self.importedAccounts = accounts
            .map { accounts in
                accounts.filter { $0.isActive && $0.imported }
            }
            .eraseToAnyPublisher()
    }

    func updateLabels(on accounts: [BitcoinChainCryptoAccount]) -> AnyPublisher<Void, Never> {
        self.accounts
            .catch { _ in [] }
            .flatMap { [accountNamingReplenishement] (btcAccounts: [BitcoinWalletAccount]) -> AnyPublisher<Void, Never> in
                let updatedAccounts: [BitcoinWalletAccount] = btcAccounts.compactMap { btcAccount in
                    if let label = accounts.first(where: { $0.hdAccountIndex == btcAccount.index })?.newForcedUpdateLabel {
                        btcAccount.updateLabel(label)
                    } else {
                        nil
                    }
                }
                let info: [AccountToRename] = updatedAccounts.map { (index: $0.index, label: $0.label) }
                return accountNamingReplenishement.updateLabels(on: info)
                    .first()
                    .ignoreFailure(setFailureType: Never.self)
                    .eraseToAnyPublisher()
            }
            .mapError()
            .mapToVoid()
            .handleEvents(
                receiveOutput: { [cachedValue] _ in
                    cachedValue.invalidateCache()
                }
            )
            .eraseToAnyPublisher()
    }
}

private func btcWalletAccount(
    from entry: BitcoinEntry.Account
) -> BitcoinWalletAccount {
    let publicKeys = entry.xpubs.map { xpub in
        XPub(address: xpub.address, derivationType: derivationType(from: xpub.type))
    }
    return BitcoinWalletAccount(
        index: entry.index,
        label: entry.label,
        archived: entry.archived,
        publicKeys: .left(XPubs(xpubs: publicKeys))
    )
}

private func btcWalletAccount(
    from address: BitcoinEntry.ImportedAddress
) -> BitcoinWalletAccount {
    let xpub = XPub(address: address.addr, derivationType: .legacy)
    return BitcoinWalletAccount(
        index: 0,
        label: address.label ?? "",
        archived: address.archived,
        publicKeys: .right(xpub),
        importedPrivateKey: address.priv,
        imported: true
    )
}
