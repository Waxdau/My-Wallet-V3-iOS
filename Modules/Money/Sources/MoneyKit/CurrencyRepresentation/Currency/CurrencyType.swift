// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

public enum CurrencyType: Hashable, Codable {

    /// A fiat currency.
    case fiat(FiatCurrency)

    /// A crypto currency.
    case crypto(CryptoCurrency)

    /// Creates a currency type.
    ///
    /// - Parameters:
    ///   - code:                     A currency code.
    ///   - currenciesService: An enabled currencies service.
    ///
    /// - Throws: A `CurrencyError.unknownCurrency` if `code` is invalid.
    public init(code: String, service: EnabledCurrenciesServiceAPI = EnabledCurrenciesService.default) throws {
        if let cryptoCurrency = CryptoCurrency(code: code, service: service) {
            self = .crypto(cryptoCurrency)
            return
        }

        if let fiatCurrency = FiatCurrency(code: code) {
            self = .fiat(fiatCurrency)
            return
        }

        throw CurrencyError.unknownCurrency
    }

    public static func == (lhs: CurrencyType, rhs: FiatCurrency) -> Bool {
        switch lhs {
        case crypto:
            false
        case fiat(let lhs):
            lhs == rhs
        }
    }

    public static func == (lhs: CurrencyType, rhs: CryptoCurrency) -> Bool {
        switch lhs {
        case crypto(let lhs):
            lhs == rhs
        case fiat:
            false
        }
    }

    public init(from decoder: Decoder) throws {
        do {
            self = try .crypto(CryptoCurrency(from: decoder))
        } catch {
            self = try .fiat(FiatCurrency(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .fiat(let currency):
            try currency.encode(to: encoder)
        case .crypto(let currency):
            try currency.encode(to: encoder)
        }
    }
}

extension CurrencyType: Currency {

    public static let maxDisplayPrecision: Int = max(FiatCurrency.maxDisplayPrecision, CryptoCurrency.maxDisplayPrecision)

    public var name: String {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.name
        case .fiat(let fiatCurrency):
            fiatCurrency.name
        }
    }

    public var code: String {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.code
        case .fiat(let fiatCurrency):
            fiatCurrency.code
        }
    }

    public var displayCode: String {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.displayCode
        case .fiat(let fiatCurrency):
            fiatCurrency.displayCode
        }
    }

    public var displaySymbol: String {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.displaySymbol
        case .fiat(let fiatCurrency):
            fiatCurrency.displaySymbol
        }
    }

    public var precision: Int {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.precision
        case .fiat(let fiatCurrency):
            fiatCurrency.precision
        }
    }

    public var storeExtraPrecision: Int {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.storeExtraPrecision
        case .fiat(let fiatCurrency):
            fiatCurrency.storeExtraPrecision
        }
    }

    public var displayPrecision: Int {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency.displayPrecision
        case .fiat(let fiatCurrency):
            fiatCurrency.displayPrecision
        }
    }

    public var isFiatCurrency: Bool {
        switch self {
        case .crypto:
            false
        case .fiat:
            true
        }
    }

    public var isCryptoCurrency: Bool {
        switch self {
        case .crypto:
            true
        case .fiat:
            false
        }
    }

    public var currencyType: CurrencyType { self }

    /// The crypto currency, or `nil` if not a crypto currency.
    public var cryptoCurrency: CryptoCurrency? {
        switch self {
        case .crypto(let cryptoCurrency):
            cryptoCurrency
        case .fiat:
            nil
        }
    }

    /// The fiat currency, or `nil` if not a fiat currency.
    public var fiatCurrency: FiatCurrency? {
        switch self {
        case .crypto:
            nil
        case .fiat(let fiatCurrency):
            fiatCurrency
        }
    }
}

extension CryptoCurrency {
    public var currencyType: CurrencyType {
        .crypto(self)
    }
}

extension FiatCurrency {
    public var currencyType: CurrencyType {
        .fiat(self)
    }
}

extension CryptoValue {
    public var currencyType: CurrencyType {
        currency.currencyType
    }
}

extension FiatValue {
    public var currencyType: CurrencyType {
        currency.currencyType
    }
}
