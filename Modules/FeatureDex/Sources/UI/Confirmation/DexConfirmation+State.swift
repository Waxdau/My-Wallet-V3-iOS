// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ComposableArchitecture
import FeatureDexDomain
import MoneyKit
import SwiftUI

extension DexConfirmation {
    public struct State: Hashable {
        var quote: Quote
        var newQuote: Quote?
        var priceUpdated: Bool { newQuote != nil }
        var balances: [DexBalance]
        @BindingState var didConfirm: Bool = false
        @BindingState var pendingTransaction: PendingTransaction.State?
        @BindingState var networkFiatExchangeRate: MoneyValue?
        @BindingState var fromFiatExchangeRate: MoneyValue?
        @BindingState var toFiatExchangeRate: MoneyValue?

        var sourceBalance: DexBalance? {
            balances.first(where: { $0.currency == quote.from.currency })
        }

        var destinationBalance: DexBalance? {
            balances.first(where: { $0.currency == quote.to.currency })
        }
    }
}

extension DexConfirmation.State {
    public struct Quote: Hashable {
        var enoughBalance: Bool
        var from: CryptoValue
        var minimumReceivedAmount: CryptoValue
        var networkFee: CryptoValue
        var slippage: Double
        var to: CryptoValue
        var exchangeRate: MoneyValuePair {
            MoneyValuePair(base: from.moneyValue, quote: to.moneyValue).exchangeRate
        }
    }
}

extension DexConfirmation.State.Quote {
    static func preview(from: CryptoCurrency = .ethereum, to: CryptoCurrency = .bitcoin) -> DexConfirmation.State.Quote {
        DexConfirmation.State.Quote(
            enoughBalance: true,
            from: CryptoValue.create(major: 0.05, currency: from),
            minimumReceivedAmount: CryptoValue.create(major: 61.92, currency: to),
            networkFee: CryptoValue.create(major: 0.005, currency: from),
            slippage: 0.0013,
            to: CryptoValue.create(major: 399917.445189445, currency: to)
        )
    }
}

extension DexConfirmation.State {

    static var preview: DexConfirmation.State = DexConfirmation.State(
        quote: .preview(),
        balances: [
            .init(value: .one(currency: .ethereum)),
            .init(value: .one(currency: .bitcoin))
        ]
    )
}
