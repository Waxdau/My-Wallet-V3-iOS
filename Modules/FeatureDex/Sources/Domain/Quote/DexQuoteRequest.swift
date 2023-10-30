// Copyright © Blockchain Luxembourg S.A. All rights reserved.

public struct DexQuoteRequest: Encodable, Equatable {

    public struct CurrencyParams: Encodable, Equatable {
        var chainId: Int
        var symbol: String
        var address: String
        var amount: String?

        public init(chainId: Int, symbol: String, address: String, amount: String?) {
            self.chainId = chainId
            self.symbol = symbol
            self.address = address
            self.amount = amount
        }
    }

    public struct Params: Encodable, Equatable {
        public var slippage: String
        public var skipValidation: Bool
        public var enableBoost: Bool
        public var receiveGasOnDestination: Bool

        public init(slippage: String, skipValidation: Bool, enableBoost: Bool, receiveGasOnDestination: Bool) {
            self.slippage = slippage
            self.skipValidation = skipValidation
            self.enableBoost = enableBoost
            self.receiveGasOnDestination = receiveGasOnDestination
        }
    }

    public var fromCurrency: CurrencyParams
    public var toCurrency: CurrencyParams
    private var takerAddress: String
    public var params: Params

    public init(
        fromCurrency: CurrencyParams,
        toCurrency: CurrencyParams,
        takerAddress: String,
        params: Params
    ) {
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.takerAddress = takerAddress
        self.params = params
    }
}
