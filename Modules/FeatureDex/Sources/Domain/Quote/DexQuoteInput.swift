// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import MoneyKit

public struct DexQuoteInput {
    public let amount: InputAmount
    public let source: CryptoCurrency
    public let destination: CryptoCurrency
    public let skipValidation: Bool
    public let slippage: Double
    public let expressMode: Bool
    public let gasOnDestination: Bool
    public let takerAddress: String

    public init(
        amount: InputAmount,
        source: CryptoCurrency,
        destination: CryptoCurrency,
        skipValidation: Bool,
        slippage: Double,
        expressMode: Bool,
        gasOnDestination: Bool,
        takerAddress: String
    ) {
        self.takerAddress = takerAddress
        self.amount = amount
        self.source = source
        self.destination = destination
        self.slippage = slippage
        self.expressMode = expressMode
        self.gasOnDestination = gasOnDestination
        self.skipValidation = skipValidation
    }
}

public enum InputAmount {
    case source(CryptoValue)
    case destination(CryptoValue)

    public var source: CryptoValue? {
        switch self {
        case .source(let value):
            return value
        case .destination:
            return nil
        }
    }

    public var destination: CryptoValue? {
        switch self {
        case .source:
            return nil
        case .destination(let value):
            return value
        }
    }
}
