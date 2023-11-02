// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import MoneyKit

public protocol CryptoAsset: Asset {

    var asset: CryptoCurrency { get }

    /// Gives a chance for the `CryptoAsset` to initialize itself.
    func initialize() -> AnyPublisher<Void, AssetError>

    var defaultAccount: AnyPublisher<SingleAccount, CryptoAssetError> { get }

    var canTransactToCustodial: AnyPublisher<Bool, Never> { get }

    var addressFactory: ExternalAssetAddressFactory { get }

    func parse(
        address: String,
        memo: String?,
        label: String,
        onTxCompleted: @escaping (TransactionResult) -> AnyPublisher<Void, Error>
    ) -> Result<CryptoReceiveAddress, CryptoReceiveAddressFactoryError>
}

extension CryptoAsset {

    /// Forces wallets with the previous legacy label to the new default label.
    public func upgradeLegacyLabels(accounts: [BlockchainAccount]) -> AnyPublisher<Void, Never> {
        let publishers: [AnyPublisher<Void, Never>] = accounts
            // Optional cast each element in the array to `CryptoNonCustodialAccount`.
            .compactMap { $0 as? CryptoNonCustodialAccount }
            // Filter in elements that need `labelNeedsForcedUpdate`.
            .filter(\.labelNeedsForcedUpdate)
            // Map to infallible Publisher jobs.
            .map { account in
                // Updates this account label with new default.
                account.updateLabel(account.newForcedUpdateLabel)
            }

        return Deferred {
            publishers
                .merge()
                .collect()
        }
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    /// Possible transaction targets this `Asset` has for a transaction initiating from the given `SingleAccount`.
    public func transactionTargets(
        account: SingleAccount,
        action: AssetAction
    ) -> AnyPublisher<[SingleAccount], Never> {
        guard let crypto = account as? CryptoAccount else {
            fatalError("Expected a CryptoAccount: \(account).")
        }
        guard crypto.asset == asset else {
            fatalError("Expected asset to be the same.")
        }
        switch crypto {
        case is TradingAccount,
             is NonCustodialAccount:
            return canTransactToCustodial
                .flatMap { [accountGroup] canTransactToCustodial -> AnyPublisher<AccountGroup?, Never> in
                    accountGroup(canTransactToCustodial ? action.allFilterType : .nonCustodial)
                }
                .compactMap { $0 }
                .map(\.accounts)
                .mapFilter(excluding: crypto.identifier)
                .eraseToAnyPublisher()
        default:
            fatalError("unimplemented")
        }
    }
}

extension AssetAction {
    fileprivate var allFilterType: AssetFilter {
        switch self {
        case .send:
            .all
        case .buy,
                .deposit,
                .interestTransfer,
                .interestWithdraw,
                .stakingDeposit,
                .stakingWithdraw,
                .receive,
                .sell,
                .sign,
                .swap,
                .viewActivity,
                .withdraw,
                .activeRewardsDeposit,
                .activeRewardsWithdraw:
            .allExcludingExchange
        }
    }
}

extension CryptoNonCustodialAccount {

    private var legacyLabels: [String?] {
        [asset.legacyLabel, asset.privateKeyWalletLegacyLabel]
    }

    /// Replaces the part of this wallet label that matches the previous default wallet label with the new default label.
    /// To be used only during the forced wallet label update.
    public var newForcedUpdateLabel: String {
        legacyLabels
            .compactMap { $0 }
            .reduce(into: "") { partialResult, value in
                if label.localizedStandardContains(value) {
                    partialResult = label.replacingOccurrences(
                        of: value,
                        with: NonL10n.defiWalletTitle,
                        options: [.caseInsensitive]
                    )
                }
            }
    }

    /// If this account label need to be updated to the new default label.
    /// To be used only during the forced wallet label update.
    public var labelNeedsForcedUpdate: Bool {
        legacyLabels
            .compactMap { $0 }
            .any { value in
                currentLabelContains(value)
            }
    }

    private func currentLabelContains(_ value: String) -> Bool {
        label.localizedStandardContains(value)
    }
}

extension CryptoCurrency {

    fileprivate var privateKeyWalletLegacyLabel: String? {
        switch self {
        case .bitcoin,
            .bitcoinCash,
            .ethereum,
            .stellar:
            L10n.legacyPrivateKeyWallet
        default:
            // Any other existing or future asset does not need forced wallet name upgrade.
            nil
        }
    }

    /// The default label for this asset, it may not be a localized string.
    /// To be used only during the forced wallet label update.
    fileprivate var legacyLabel: String? {
        switch self {
        case .bitcoin:
            L10n.legacyMyBitcoinWallet
        case .bitcoinCash:
            // Legacy BCH label is not localized.
            "My Bitcoin Cash Wallet"
        case .ethereum:
            // Legacy ETH label is not localized.
            "My Ether Wallet"
        case .stellar:
            // Legacy XLM label is not localized.
            "My Stellar Wallet"
        default:
            // Any other existing or future asset does not need forced wallet name upgrade.
            nil
        }
    }
}
