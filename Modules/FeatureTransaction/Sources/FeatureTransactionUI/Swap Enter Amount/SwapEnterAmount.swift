// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import ComposableArchitecture
import FeatureTransactionDomain
import Foundation
import Localization
import MoneyKit
import PlatformKit
import AnalyticsKit
import DIKit

public struct SwapEnterAmount: ReducerProtocol {
    var defaultSwapPairsService: DefaultSwapCurrencyPairsServiceAPI
    var app: AppProtocol
    public var dismiss: () -> Void
    public var onSwapAccountsSelected: (String, String, MoneyValue) -> Void

    public init(
        app: AppProtocol,
        defaultSwaptPairsService: DefaultSwapCurrencyPairsServiceAPI,
        dismiss: @escaping () -> Void,
        onSwapAccountsSelected: @escaping (String, String, MoneyValue) -> Void
    ) {
        self.defaultSwapPairsService = defaultSwaptPairsService
        self.app = app
        self.dismiss = dismiss
        self.onSwapAccountsSelected = onSwapAccountsSelected
    }

    // MARK: - State

    public struct State: Equatable {
        @BindingState var targetInformation: SelectionInformation?
        @BindingState var showAccountSelect: Bool = false
        @BindingState var sourceBalance: MoneyValue?
        @BindingState var sourceValuePrice: MoneyValue?
        @BindingState var defaultFiatCurrency: FiatCurrency?
        var isEnteringFiat: Bool = true
        var sourceInformation: SelectionInformation?
        var selectFromCryptoAccountState: SwapFromAccountSelect.State?
        var selectToCryptoAccountState: SwapToAccountSelect.State?
        var fullInputText: String = "" {
            didSet {
                updateAmounts()
            }
        }

        public init() {}

        var previewButtonDisabled: Bool {
            finalSelectedMoneyValue == nil || finalSelectedMoneyValue?.isZero == true
        }

        var transactionDetails: (forbidden: Bool, ctaLabel: String) {
            guard let defaultFiatCurrency,
                  let maxAmountToSwap,
                  let currentEnteredMoneyValue = isEnteringFiat ? amountFiatEntered : amountCryptoEntered,
                  let amountFiatEntered = amountFiatEntered?.fiatValue
            else {
                return (forbidden: false, ctaLabel: LocalizationConstants.Swap.previewSwap)
            }


            let minimumSwapFiatValue = FiatValue.create(major: Decimal(5), currency: defaultFiatCurrency)
            if (try? amountFiatEntered < FiatValue.create(major: Decimal(5), currency: defaultFiatCurrency)) ?? false {
                return (
                    forbidden: true,
                    ctaLabel: String.localizedStringWithFormat(
                        LocalizationConstants.Swap.belowMinimumLimitCTA,
                        minimumSwapFiatValue.toDisplayString(includeSymbol: true)
                    )
                )
            }

            if (try? currentEnteredMoneyValue > maxAmountToSwap) ?? false {
                return (
                    forbidden: true,
                    ctaLabel: String.localizedStringWithFormat(
                        LocalizationConstants.Swap.notEnoughCoin,
                        sourceInformation?.currency.code ?? ""
                    )
                )
            }

            return (forbidden: false, ctaLabel: LocalizationConstants.Swap.previewSwap)
        }

        var finalSelectedMoneyValue: MoneyValue? {
            if isEnteringFiat {
                return amountFiatEntered?
                    .toCryptoAmount(
                        currency: sourceInformation?.currency.currencyType.cryptoCurrency,
                        cryptoPrice: sourceValuePrice
                    )
            } else {
                return amountCryptoEntered
            }
        }

        var mainFieldText: String {
            if isEnteringFiat {
                return amountFiatEntered?.fiatValue?.toDisplayString(includeSymbol: true, format: .shortened) ?? defaultZeroFiat
            } else {
                return amountCryptoEntered?.toDisplayString(includeSymbol: true) ?? defaultZeroCryptoCurrency
            }
        }

        var secondaryFieldText: String {
            if isEnteringFiat == true {
                return amountFiatEntered?
                    .toCryptoAmount(
                        currency: sourceInformation?.currency.currencyType.cryptoCurrency,
                        cryptoPrice: sourceValuePrice
                    )?
                    .displayString
                ?? defaultZeroCryptoCurrency
            } else {
                return amountCryptoEntered?
                    .cryptoValue?
                    .toFiatAmount(with: sourceValuePrice)?
                    .toDisplayString(includeSymbol: true, format: .shortened) ?? defaultZeroFiat
            }
        }

        private var defaultZeroFiat: String {
            defaultFiatCurrency.flatMap(FiatValue.zero(currency:))?.toDisplayString(includeSymbol: true, format: .shortened) ?? ""
        }

        private var defaultZeroCryptoCurrency: String {
            guard let currency = sourceInformation?.currency else {
                return ""
            }
            return CryptoValue(storeAmount: 0, currency: currency).toDisplayString(includeSymbol: true)
        }


        var maxAmountToSwapFiatValue: MoneyValue? {
            return sourceBalance?.cryptoValue?.toFiatAmount(with: sourceValuePrice)?.moneyValue
        }

        var maxAmountToSwapCryptoValue: MoneyValue? {
            sourceBalance
        }

        var maxAmountToSwap: MoneyValue? {
            if isEnteringFiat {
                return sourceBalance?.cryptoValue?.toFiatAmount(with: sourceValuePrice)?.moneyValue
            } else {
                return sourceBalance
            }
        }

        var currentEnteredMoneyValue: MoneyValue? {
            if isEnteringFiat {
                return amountFiatEntered
            } else {
                return amountCryptoEntered
            }
        }

        var amountFiatEntered: MoneyValue?
        var amountCryptoEntered: MoneyValue?

        mutating func updateAmounts() {
            guard let currency = defaultFiatCurrency else {
                return
            }

            guard let sourceCurrency = sourceInformation?.currency.currencyType.cryptoCurrency else {
                return
            }


            amountFiatEntered = MoneyValue
                .create(
                    major: fullInputText,
                    currency: currency.currencyType
                )

            amountCryptoEntered = MoneyValue.create(
                minor: fullInputText,
                currency: sourceCurrency.currencyType
            )
        }

    }

    // MARK: - Action

    public enum Action: BindableAction {
        case onAppear
        case didFetchPairs(SelectionInformation, SelectionInformation)
        case didFetchSourceBalance(MoneyValue?)
        case onPreviewTapped
        case onChangeInputTapped
        case onMaxButtonTapped
        case binding(BindingAction<SwapEnterAmount.State>)
        case onSelectFromCryptoAccountAction(SwapFromAccountSelect.Action)
        case onSelectToCryptoAccountAction(SwapToAccountSelect.Action)
        case onSelectSourceTapped
        case onSelectTargetTapped
        case updateSourceBalance
        case resetTarget
        case checkTarget
        case onCloseTapped
        case onInputChanged(String)
        case resetInput
    }

    // MARK: - Reducer

    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Scope(state: \.self, action: /Action.self) {
            SwapEnterAmountAnalytics(app: app)
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [sourceInformation = state.sourceInformation, targetInformation = state.targetInformation] send in
                    guard sourceInformation == nil, targetInformation == nil else {
                        return
                    }
                    if let pairs = await defaultSwapPairsService.getDefaultPairs() {
                        await send(.didFetchPairs(pairs.0, pairs.1))
                        await send(.updateSourceBalance)
                    }
                }

            case .didFetchSourceBalance(let moneyValue):
                state.sourceBalance = moneyValue
                return .none

            case .updateSourceBalance:
                let sourceCurrencyCode = state.sourceInformation?.currency.code
                return .run { send in
                    let appMode = await app.mode()
                    switch appMode {
                    case .pkw:
                        let balance = try? await app.get(blockchain.user.pkw.asset[sourceCurrencyCode].balance, as: MoneyValue.self)
                        await send(.didFetchSourceBalance(balance))
                    case .trading, .universal:
                        let balance = try? await app.get(blockchain.user.trading.account[sourceCurrencyCode].balance.available, as: MoneyValue.self)
                        await send(.didFetchSourceBalance(balance))
                    }
                }

            case .didFetchPairs(let sourcePair, let targetPair):
                state.sourceInformation = sourcePair
                state.targetInformation = targetPair
                return .none

            case .onInputChanged(let text):
                state.fullInputText.appendAndFormat(text)
                return .none

            case .onChangeInputTapped:
                state.isEnteringFiat.toggle()
                return EffectTask(value: .resetInput)

            case .checkTarget:
                return .run { [source = state.sourceInformation?.currency, target = state.targetInformation?.currency] send in
                    if let tradingPairs = try? await app.get(blockchain.api.nabu.gateway.trading.swap.pairs, as: [TradingPair].self),
                       tradingPairs.filter({ $0.sourceCurrencyType.code == source?.code && $0.destinationCurrencyType.code == target?.code }).isEmpty {
                        await send(.resetTarget)
                    }
                }

            case .resetTarget:
                state.targetInformation = nil
                return .none

            case .onMaxButtonTapped:
                if state.isEnteringFiat {
                    state.amountFiatEntered = state.maxAmountToSwapFiatValue
                } else {
                    state.amountCryptoEntered = state.maxAmountToSwapCryptoValue
                }
                return .none

            case .onSelectSourceTapped:
                state.selectFromCryptoAccountState = SwapFromAccountSelect.State(appMode: app.currentMode)
                state.showAccountSelect.toggle()
                return .none

            case .onSelectTargetTapped:
                state.selectToCryptoAccountState = SwapToAccountSelect.State(
                    selectedSourceCrypto: state.sourceInformation?.currency,
                    appMode: app.currentMode
                )
                state.showAccountSelect.toggle()
                return .none

            case .binding(\.$showAccountSelect):
                if state.showAccountSelect == false {
                    state.selectFromCryptoAccountState = nil
                    state.selectToCryptoAccountState = nil
                }
                return .none

            case .binding:
                return .none

            case .onPreviewTapped:
                if let sourceAccountId = state.sourceInformation?.accountId,
                   let targetAccountId = state.targetInformation?.accountId,
                   let amountCryptoEntered = state.finalSelectedMoneyValue
                {
                    onSwapAccountsSelected(sourceAccountId, targetAccountId, amountCryptoEntered)
                }
                return .none

            case .onCloseTapped:
                dismiss()
                return .none

            case .onSelectFromCryptoAccountAction(let action):
                switch action {
                case .onCloseTapped:
                    state.showAccountSelect = false
                    return .none

                case .accountRow(let id, let action):
                    guard action == .onAccountSelected else { return .none }
                    if let selectedAccountRow = state.selectFromCryptoAccountState?.swapAccountRows.filter({ $0.id == id }).first,
                       let currency = selectedAccountRow.currency
                    {
                        state.sourceInformation = SelectionInformation(
                            accountId: id,
                            currency: currency
                        )
                        state.showAccountSelect.toggle()
                        return .merge(
                            EffectTask(value: .updateSourceBalance),
                            EffectTask(value: .checkTarget)
                        )
                    }
                    return .none
                default:
                    return .none
                }

            case .onSelectToCryptoAccountAction(let action):
                switch action {
                case .onCloseTapped:
                    state.showAccountSelect = false
                    return .none

                case .accountRow(_, .onAccountSelected(let accountId)):
                    state.showAccountSelect.toggle()
                    return .run { send in
                        if let currency = try? await app.get(blockchain.coin.core.account[accountId].currency, as: CryptoCurrency.self) {
                            await send(.binding(.set(\.$targetInformation, SelectionInformation(accountId: accountId, currency: currency))))
                        }
                    }

                case .accountRow:
                    return .none

                default:
                    return .none
                }

            case .resetInput:
                state.amountFiatEntered = nil
                state.amountCryptoEntered = nil
                state.fullInputText = ""
                return .none
            }
        }
        .ifLet(\.selectFromCryptoAccountState, action: /Action.onSelectFromCryptoAccountAction, then: {
            SwapFromAccountSelect(app: app,
                                  supportedPairsInteractorService: resolve())
        })
        .ifLet(\.selectToCryptoAccountState, action: /Action.onSelectToCryptoAccountAction, then: {
            SwapToAccountSelect(app: app)
        })
    }
}

extension CryptoValue {
    func toFiatAmount(with sourceValuePrice: MoneyValue?) -> FiatValue? {
        guard let sourceValuePrice else {
            return nil
        }
        let moneyValuePair = MoneyValuePair(
            base: .one(currency: currency),
            quote: sourceValuePrice
        )
        return try? moneyValue
            .convert(using: moneyValuePair)
            .fiatValue
    }
}

extension MoneyValue {
    func toCryptoAmount(
        currency: CryptoCurrency?,
        cryptoPrice: MoneyValue?
    ) -> MoneyValue? {
        guard let currency else {
            return nil
        }

        guard let exchangeRate = cryptoPrice else {
            return nil
        }

        let exchange = MoneyValuePair(
            base: .one(currency: .crypto(currency)),
            quote: exchangeRate
        )
            .inverseExchangeRate

        return try? convert(using: exchange)
    }
}

private extension String {
    var digits: String {
        let both = CharacterSet.decimalDigits.union(CharacterSet (charactersIn: ".")).inverted
        return components(separatedBy: both)
            .joined()
    }

    mutating func appendAndFormat(_ other: String) {
        if other == "delete" {
            // Delete the last character
            if !isEmpty {
                removeLast()
            }

            // If the last remaining character is ".", delete it
            if last == "." {
                removeLast()
            }
        } else {
            let decimalIndex = firstIndex(of: ".")
            let shouldAppend = decimalIndex == nil || decimalIndex.map { self.distance(from: $0, to: self.endIndex) < 3 } ?? true

            if shouldAppend {
                append(other)
            }

            let regexPattern = "(\\.)(?=.*\\.)"
            let regex = try! NSRegularExpression(pattern: regexPattern, options: [])
            let range = NSRange(location: 0, length: utf16.count)

            let formattedString = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
            self = formattedString
        }
    }
}


