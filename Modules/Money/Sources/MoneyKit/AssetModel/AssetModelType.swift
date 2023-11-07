// Copyright © Blockchain Luxembourg S.A. All rights reserved.

/// A type of an `AssetModel`.
public enum AssetModelType: Hashable {

    public enum CeloParentChain: String {
        case celo = "CELO"
    }

    /// A Celo token asset.
    case celoToken(parentChain: CeloParentChain)

    /// A coin asset.
    case coin(minimumOnChainConfirmations: Int)

    /// An Ethereum ERC-20 asset.
    case erc20(contractAddress: String, parentChain: String)

    /// A fiat asset.
    case fiat

    public var erc20ContractAddress: String? {
        switch self {
        case .erc20(let contractAddress, _):
            contractAddress
        case .coin, .fiat, .celoToken:
            nil
        }
    }

    public var erc20ParentChain: String? {
        switch self {
        case .erc20(_, let parentChain):
            parentChain
        case .coin, .fiat, .celoToken:
            nil
        }
    }

    public var isERC20: Bool {
        switch self {
        case .erc20:
            true
        case .coin, .fiat, .celoToken:
            false
        }
    }

    public var isCoin: Bool {
        switch self {
        case .coin:
            true
        case .erc20, .fiat, .celoToken:
            false
        }
    }

    public var isCeloToken: Bool {
        switch self {
        case .celoToken:
            true
        case .coin, .erc20, .fiat:
            false
        }
    }
}
