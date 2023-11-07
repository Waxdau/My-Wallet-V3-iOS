// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import Foundation

public struct AssetFilter: OptionSet, Hashable, Codable {

    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let custodial = AssetFilter(rawValue: 1 << 0)
    public static let nonCustodial = AssetFilter(rawValue: 1 << 1)
    public static let interest = AssetFilter(rawValue: 1 << 2)
    public static let exchange = AssetFilter(rawValue: 1 << 3)
    public static let staking = AssetFilter(rawValue: 1 << 4)
    public static let activeRewards = AssetFilter(rawValue: 1 << 5)

    /// This is only used on a specific case, refrain from adding this to a group of `AssetFilter`(s)
    public static let nonCustodialImported = AssetFilter(rawValue: 1 << 6)

    public static let all: AssetFilter = [.custodial, .nonCustodial, .interest, .exchange, .staking, .activeRewards]
    public static let allExcludingExchange: AssetFilter = [.custodial, .nonCustodial, .interest, .staking, .activeRewards]
    public static let allCustodial: AssetFilter = [.custodial, .interest, .staking, .activeRewards]
}

extension AppMode {
    public var filter: AssetFilter {
        switch self {
        case .pkw:
            .nonCustodial
        case .trading:
            [.custodial, .interest, .staking, .activeRewards]
        }
    }
}
