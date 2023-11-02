import Blockchain

public struct SwapCheckout: Equatable {

    public var from: Target
    public var to: Target
    public var quoteExpiration: Date?

    public var exchangeRate: MoneyValuePair {
        MoneyValuePair(base: from.cryptoValue.moneyValue, quote: to.cryptoValue.moneyValue).exchangeRate
    }

    public var totalFeesInFiat: FiatValue? {
        switch (from.feeFiatValue, to.feeFiatValue) {
        case (let x?, let y?) where !(from.fee.isZero && to.fee.isZero):
            try? x + y
        case (let x?, nil) where from.fee.isNotZero:
            x
        case (nil, let y?) where to.fee.isNotZero:
            y
        default:
            nil
        }
    }

    public init(
        from: Target,
        to: Target,
        quoteExpiration: Date? = nil
    ) {
        self.from = from
        self.to = to
        self.quoteExpiration = quoteExpiration
    }
}

extension SwapCheckout {

    public struct Target: Equatable {
        public var name: String
        public var isPrivateKey: Bool
        public var cryptoValue: CryptoValue
        public var fee: CryptoValue
        public var exchangeRateToFiat: MoneyValuePair?
        public var feeExchangeRateToFiat: MoneyValuePair?

        public var fiatValue: FiatValue? {
            exchangeRateToFiat.flatMap { exchangeRate in
                try? cryptoValue.moneyValue.convert(using: exchangeRate)
            }?
                .fiatValue?
                .displayableRounding(roundingMode: .up)
        }

        public var feeFiatValue: FiatValue? {
            feeExchangeRateToFiat.flatMap { exchangeRate in
                try? fee.moneyValue.convert(using: exchangeRate)
            }?
                .fiatValue
        }

        public var code: String {
            cryptoValue.code
        }

        public var feeCode: String {
            fee.code
        }

        public var amountFiatValueAddFee: FiatValue? {
            guard let fiatValue, let feeFiatValue else {
                return nil
            }
            return try? fiatValue + feeFiatValue
        }

        public var amountFiatValueSubtractFee: FiatValue? {
            guard let fiatValue, let feeFiatValue else {
                return nil
            }
            return try? fiatValue - feeFiatValue
        }

        public init(
            name: String,
            isPrivateKey: Bool,
            cryptoValue: CryptoValue,
            fee: CryptoValue,
            exchangeRateToFiat: MoneyValuePair?,
            feeExchangeRateToFiat: MoneyValuePair?
        ) {
            self.name = name
            self.isPrivateKey = isPrivateKey
            self.cryptoValue = cryptoValue
            self.fee = fee
            self.exchangeRateToFiat = exchangeRateToFiat
            self.feeExchangeRateToFiat = feeExchangeRateToFiat
        }
    }
}

extension SwapCheckout {

    public static let preview = SwapCheckout(
        from: Target(
            name: "Private Key Wallet",
            isPrivateKey: true,
            cryptoValue: .create(minor: 12315135, currency: .bitcoin),
            fee: .create(minor: 1312, currency: .bitcoin),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            )
        ),
        to: Target(
            name: "Private Key Wallet",
            isPrivateKey: true,
            cryptoValue: .create(minor: 1221412442357135135, currency: .ethereum),
            fee: .create(minor: 12321422414515, currency: .ethereum),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            )
        ),
        quoteExpiration: Date().addingTimeInterval(60)
    )

    public static let previewPrivateKeyToPrivateKeyNoTargetFees = SwapCheckout(
        from: Target(
            name: "Private Key Wallet",
            isPrivateKey: true,
            cryptoValue: .create(minor: 12315135, currency: .ethereum),
            fee: .create(minor: 1312, currency: .ethereum),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            )
        ),
        to: Target(
            name: "Private Key Wallet",
            isPrivateKey: true,
            cryptoValue: .create(minor: 1221412442357135135, currency: .stellar),
            fee: .zero(currency: .stellar),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .stellar),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .stellar),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            )
        ),
        quoteExpiration: Date().addingTimeInterval(60)
    )

    public static let previewPrivateKeyToTrading = SwapCheckout(
        from: Target(
            name: "Private Key Wallet",
            isPrivateKey: true,
            cryptoValue: .create(minor: 12315135, currency: .bitcoin),
            fee: .create(minor: 1312, currency: .bitcoin),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            )
        ),
        to: Target(
            name: "Trading Wallet",
            isPrivateKey: false,
            cryptoValue: .create(minor: 1221412442357135135, currency: .ethereum),
            fee: .create(minor: 12321422414515, currency: .ethereum),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            )
        ),
        quoteExpiration: Date().addingTimeInterval(60)
    )

    public static let previewTradingToTrading = SwapCheckout(
        from: Target(
            name: "Trading Wallet",
            isPrivateKey: false,
            cryptoValue: .create(minor: 12315135, currency: .bitcoin),
            fee: .create(minor: 1312, currency: .bitcoin),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            )
        ),
        to: Target(
            name: "Trading Wallet",
            isPrivateKey: false,
            cryptoValue: .create(minor: 1221412442357135135, currency: .ethereum),
            fee: .create(minor: 12321422414515, currency: .ethereum),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            )
        ),
        quoteExpiration: Date().addingTimeInterval(60)
    )

    public static let previewTradingToTradingNoFees = SwapCheckout(
        from: Target(
            name: "Trading Wallet",
            isPrivateKey: false,
            cryptoValue: .create(minor: 12315135, currency: .bitcoin),
            fee: .create(minor: 1312, currency: .bitcoin),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .bitcoin),
                quote: FiatValue.create(major: 26225.2, currency: .USD).moneyValue
            )
        ),
        to: Target(
            name: "Trading Wallet",
            isPrivateKey: false,
            cryptoValue: .create(minor: 1221412442357135135, currency: .ethereum),
            fee: .zero(currency: .ethereum),
            exchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            ),
            feeExchangeRateToFiat: MoneyValuePair(
                base: .one(currency: .ethereum),
                quote: FiatValue.create(major: 1987.2, currency: .USD).moneyValue
            )
        ),
        quoteExpiration: Date().addingTimeInterval(60)
    )
}
