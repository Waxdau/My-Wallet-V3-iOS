// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import Combine
import ComposableArchitecture
import DelegatedSelfCustodyDomain
import DIKit
import Errors
import FeatureDexData
import FeatureDexDomain
import Foundation
import MoneyKit
import SwiftUI

public struct DexMain: Reducer {
    @Dependency(\.dexService) var dexService
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.app) var app

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.source, action: /Action.sourceAction) {
            DexCell()
        }
        Scope(state: \.destination, action: /Action.destinationAction) {
            DexCell()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let balances = Effect.publisher {
                    dexService.balancesStream()
                        .receive(on: mainQueue)
                        .map(Action.onBalances)
                }
                .cancellable(id: CancellationID.balances, cancelInFlight: true)

                var supportedTokens = Effect<DexMain.Action>.none
                if state.destination.supportedTokens.isEmpty {
                    supportedTokens = Effect.publisher {
                        dexService.supportedTokens()
                            .receive(on: mainQueue)
                            .map(Action.onSupportedTokens)
                    }
                }

                var availableNetworks = Effect<DexMain.Action>.none
                if state.availableNetworks.isEmpty {
                    availableNetworks = Effect.publisher {
                        dexService
                            .availableChainsService
                            .availableEvmChains()
                            .result()
                            .receive(on: mainQueue)
                            .map(Action.onAvailableNetworksFetched)
                    }
                } else if let network = getThatCurrency(app: app)?.network() {
                    availableNetworks = Effect.send(.onNetworkSelected(network))
                }

                let refreshQuote = Effect<Action>.send(.refreshQuote)

                return .merge(balances, supportedTokens, availableNetworks, refreshQuote)

            case .onDisappear:
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch),
                    .cancel(id: CancellationID.quoteDebounce)
                )

            case .didTapSettings:
                dismissKeyboard(&state)
                state.isSettingsShown = true
                return .none

            case .didTapFlip:
                clearAfterCurrencyChange(with: &state)
                if state.source.isCurrentInput, let amount = state.source.amount, amount.isPositive {
                    flipBalances(with: &state)
                    state.destination.isCurrentInput = true
                    state.destination.inputText = amount.toDisplayString(includeSymbol: false)
                } else if state.destination.isCurrentInput, let amount = state.destination.amount, amount.isPositive {
                    flipBalances(with: &state)
                    state.source.isCurrentInput = true
                    state.source.inputText = amount.toDisplayString(includeSymbol: false)
                } else {
                    flipBalances(with: &state)
                }
                return Effect.merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch),
                    Effect.send(.refreshQuote)
                        .debounce(
                            id: CancellationID.quoteDebounce,
                            for: .milliseconds(500),
                            scheduler: mainQueue
                        )
                )

            case .didTapPreview:
                dismissKeyboard(&state)
                state.confirmation = DexConfirmation.State(
                    quote: state.quote?.success,
                    balances: state.availableBalances ?? []
                )
                state.isConfirmationShown = true
                return .none

            case .didTapAllowance:
                dismissKeyboard(&state)
                let detents = blockchain.ui.type.action.then.enter.into.detents
                app.post(
                    event: blockchain.ux.currency.exchange.dex.allowance.tap,
                    context: [
                        blockchain.ux.currency.exchange.dex.allowance.sheet.currency: state.source.currency!.code,
                        blockchain.ux.currency.exchange.dex.allowance.sheet.allowance.spender: state.allowance.status.allowanceSpender!,
                        detents: [detents.automatic.dimension]
                    ]
                )
                return .none

                // Supported Tokens
            case .onSupportedTokens(let result):
                switch result {
                case .success(let tokens):
                    state.destination.supportedTokens = tokens
                case .failure:
                    break
                }
                return .none

                // Balances
            case .onBalances(let result):
                switch result {
                case .success(let balances):
                    return Effect.send(.updateAvailableBalances(balances))
                case .failure:
                    return .none
                }
            case .updateAvailableBalances(let availableBalances):
                state.availableBalances = availableBalances
                return .none

                // Quote
            case .refreshQuote:
                guard let preInput = quotePreInput(with: state) else {
                    return .cancel(id: CancellationID.allowanceFetch)
                }
                state.quoteFetching = true
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .publisher {
                        fetchQuote(with: preInput)
                            .receive(on: mainQueue)
                            .map(Action.onQuote)
                    }
                    .cancellable(id: CancellationID.quoteFetch, cancelInFlight: true)
                )

            case .onQuote(let result):
                if sellCurrencyChanged(state: state, newQuoteResult: result) {
                    state.allowance.result = nil
                    state.allowance.transactionHash = nil
                }
                state.quoteFetching = false
                state.quote = result
                state.confirmation?.newQuote = DexConfirmation.State.Quote(quote: result.success)
                return Effect.send(.refreshAllowance)

                // Allowance
            case .refreshAllowance:
                guard let quote = state.quote?.success, state.allowance.result != .ok else {
                    return .none
                }
                return .publisher {
                    dexService
                        .allowance(
                            app: app,
                            currency: quote.sellAmount.currency,
                            allowanceSpender: quote.allowanceSpender
                        )
                        .receive(on: mainQueue)
                        .map(Action.onAllowance)
                }
                .cancellable(id: CancellationID.allowanceFetch, cancelInFlight: true)

            case .onAllowance(let result):
                switch result {
                case .success(let allowance):
                    return Effect.send(.updateAllowance(allowance))
                case .failure:
                    return Effect.send(.updateAllowance(nil))
                }
            case .updateAllowance(let allowance):
                let willRefresh = allowance == .ok
                    && state.allowance.result != .ok
                    && state.quote?.success?.isValidated != true
                state.allowance.result = allowance
                if willRefresh {
                    return Effect.send(.refreshQuote)
                        .debounce(
                            id: CancellationID.quoteDebounce,
                            for: .milliseconds(100),
                            scheduler: mainQueue
                        )
                }
                return .none

            case .onAvailableNetworksFetched(.success(let networks)):
                let wasEmpty = state.availableNetworks.isEmpty
                state.availableNetworks = networks
                guard wasEmpty else {
                    return .none
                }
                guard let network = preselectNetwork(app: app, from: networks) else {
                    return .none
                }
                return Effect.send(.onNetworkSelected(network))

            case .onAvailableNetworksFetched(.failure):
                return .none

            case .onTransaction(let result, let quote):
                switch result {
                case .success(let transactionId):
                    let dialog = dexSuccessDialog(quote: quote, transactionId: transactionId)
                    state.confirmation?.pendingTransaction?.status = .success(dialog, quote.buyAmount.amount.currency)
                case .failure(let error):
                    state.confirmation?.pendingTransaction?.status = .error(error)
                }
                clearAfterTransaction(with: &state)
                return .none

                // Confirmation Action
            case .confirmationAction(.confirm):
                if let quote = state.quote?.success {
                    let dialog = dexInProgressDialog(quote: quote)
                    let newState = PendingTransaction.State(
                        currency: quote.sellAmount.currency,
                        status: .inProgress(dialog)
                    )
                    state.confirmation?.pendingTransaction = newState
                    return .merge(
                        .cancel(id: CancellationID.quoteFetch),
                        .publisher {
                            dexService
                                .executeTransaction(quote: quote)
                                .receive(on: mainQueue)
                                .map { output in
                                    Action.onTransaction(output, quote)
                                }
                        }
                    )
                }
                return .cancel(id: CancellationID.quoteFetch)
            case .confirmationAction:
                return .none

                // Source action
            case .sourceAction(.binding(\.$textFieldIsFocused)):
                guard state.source.textFieldIsFocused, state.source.isCurrentInput.isNo else {
                    return .none
                }
                makeSourceActive(with: &state)
                clearDuringTyping(with: &state)
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch)
                )
            case .sourceAction(.onTapBalance), .sourceAction(.binding(\.$inputText)):
                makeSourceActive(with: &state)
                clearDuringTyping(with: &state)
                return Effect.merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch),
                    Effect.send(.refreshQuote)
                        .debounce(
                            id: CancellationID.quoteDebounce,
                            for: .milliseconds(500),
                            scheduler: mainQueue
                        )
                )

            case .sourceAction(.didSelectCurrency(let balance)):
                if state.destination.currency == balance.currency {
                    dexCellClear(state: &state.destination)
                }
                state.destination.bannedToken = balance.currency
                clearAfterCurrencyChange(with: &state)
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch)
                )
            case .sourceAction(.networkPicker(.onNetworkSelected(let value))):
                if state.crossChainEnabled.isNo {
                    state.destination.parentNetwork = value
                }
                return .none

            case .sourceAction:
                return .none

                // Destination action
            case .destinationAction(.binding(\.$textFieldIsFocused)):
                guard state.destination.textFieldIsFocused, state.destination.isCurrentInput.isNo else {
                    return .none
                }
                makeDestinationActive(with: &state)
                clearDuringTyping(with: &state)
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch)
                )
            case .destinationAction(.binding(\.$inputText)):
                makeDestinationActive(with: &state)
                clearDuringTyping(with: &state)
                return Effect.merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch),
                    Effect.send(.refreshQuote)
                        .debounce(
                            id: CancellationID.quoteDebounce,
                            for: .milliseconds(500),
                            scheduler: mainQueue
                        )
                )
            case .destinationAction(.didSelectCurrency):
                clearAfterCurrencyChange(with: &state)
                return .merge(
                    .cancel(id: CancellationID.allowanceFetch),
                    .cancel(id: CancellationID.quoteFetch),
                    Effect.send(.refreshQuote)
                        .debounce(
                            id: CancellationID.quoteDebounce,
                            for: .milliseconds(100),
                            scheduler: mainQueue
                        )
                )
            case .destinationAction:
                return .none

            case .dismissKeyboard:
                dismissKeyboard(&state)
                return .none

            case .onInegibilityLearnMoreTap:
                return .run { _ in
                    let url = try? await app.get(blockchain.api.nabu.gateway.user.products.product["DEX"].ineligible.learn.more) as URL
                    let fallbackUrl = try? await app.get(blockchain.app.configuration.asset.dex.ineligibility.learn.more.url) as URL
                    try? await app.set(blockchain.ux.currency.exchange.dex.not.eligible.learn.more.tap.then.launch.url, to: url ?? fallbackUrl)
                    app.post(event: blockchain.ux.currency.exchange.dex.not.eligible.learn.more.tap)
                }

                // Binding
            case .binding(\.allowance.$transactionHash):
                guard let quote = state.quote?.success else {
                    return .none
                }
                return .publisher {
                    dexService
                        .allowancePoll(
                            app: app,
                            currency: quote.sellAmount.currency,
                            allowanceSpender: quote.allowanceSpender
                        )
                        .receive(on: mainQueue)
                        .map(Action.onAllowance)
                }
                .cancellable(id: CancellationID.allowanceFetch, cancelInFlight: true)
            case .onNetworkSelected(let network):
                guard state.availableNetworks.contains(network) else {
                    return .none
                }
                state.source.parentNetwork = network
                state.destination.parentNetwork = network
                return .none
            case .binding:
                return .none
            }
        }
        .ifLet(\.confirmation, action: /Action.confirmationAction) {
            DexConfirmation(app: app)
        }
    }
}

extension DexConfirmation.State.Quote {
    init?(quote: DexQuoteOutput?) {
        guard let quote else {
            return nil
        }
        guard let slippage = Double(quote.slippage) else {
            return nil
        }
        self = DexConfirmation.State.Quote(
            enoughBalance: true,
            from: quote.sellAmount,
            minimumReceivedAmount: quote.buyAmount.minimum ?? quote.buyAmount.amount,
            fees: quote.fees,
            slippage: slippage,
            to: quote.buyAmount.amount
        )
    }
}

extension DexConfirmation.State {
    init?(quote: DexQuoteOutput?, balances: [DexBalance]) {
        guard let quote = DexConfirmation.State.Quote(quote: quote) else {
            return nil
        }
        self.init(quote: quote, balances: balances)
    }
}

extension DexMain {

    func fetchQuote(with input: QuotePreInput) -> AnyPublisher<Result<DexQuoteOutput, UX.Error>, Never> {
        guard !input.isLowBalance else {
            let error = DexUXError.insufficientFunds(input.source)
            return .just(.failure(error))
        }
        return dexService
            .receiveAddressProvider(app, input.source)
            .map { takerAddress in
                DexQuoteInput(
                    amount: input.amount,
                    source: input.source,
                    destination: input.destination,
                    skipValidation: input.skipValidation,
                    slippage: input.slippage,
                    expressMode: input.expressMode,
                    gasOnDestination: input.gasOnDestination,
                    takerAddress: takerAddress
                )
            }
            .mapError(UX.Error.init(error:))
            .result()
            .flatMap { input -> AnyPublisher<Result<DexQuoteOutput, UX.Error>, Never> in
                switch input {
                case .success(let input):
                    return dexService.quote(input)
                case .failure(let error):
                    return .just(.failure(error))
                }
            }
            .eraseToAnyPublisher()
    }

    struct QuotePreInput {
        let amount: InputAmount
        let source: CryptoCurrency
        let destination: CryptoCurrency
        let skipValidation: Bool
        let slippage: Double
        let expressMode: Bool
        let gasOnDestination: Bool
        let isLowBalance: Bool
    }

    func quotePreInput(with state: State) -> QuotePreInput? {
        guard let source = state.source.currency else {
            return nil
        }
        guard let destination = state.destination.currency else {
            return nil
        }
        guard let amount = quotePreInputAmount(with: state) else {
            return nil
        }
        let skipValidation = state.allowance.result != .ok && !source.isCoin
        let value = QuotePreInput(
            amount: amount,
            source: source,
            destination: destination,
            skipValidation: skipValidation,
            slippage: state.settings.slippage,
            expressMode: state.settings.expressMode,
            gasOnDestination: state.settings.gasOnDestination,
            isLowBalance: state.isLowBalance
        )
        return value
    }
}

private func quotePreInputAmount(with state: DexMain.State) -> InputAmount? {
    switch (state.source.isCurrentInput, state.destination.isCurrentInput) {
    case (false, false), (true, true):
        return nil
    case (true, false):
        guard let amount = state.source.amount, amount.isPositive else {
            return nil
        }
        return .source(amount)
    case (false, true):
        guard let amount = state.destination.amount, amount.isPositive else {
            return nil
        }
        return .destination(amount)
    }
}

private func sellCurrencyChanged(state: DexMain.State, newQuoteResult: Result<DexQuoteOutput, UX.Error>) -> Bool {
    let oldSellCurrency = state.quote?.success?.sellAmount.currency
    let newSellCurrency = newQuoteResult.success?.sellAmount.currency
    if let oldSellCurrency, oldSellCurrency != newSellCurrency {
        return true
    }
    return false
}

private func clearAfterTransaction(with state: inout DexMain.State) {
    dismissKeyboard(&state)
    state.quoteFetching = false
    state.quote = nil
    state.allowance = DexMain.State.Allowance()
    dexCellClear(state: &state.destination)
    state.source.inputText = ""
}

private func clearAfterCurrencyChange(with state: inout DexMain.State) {
    dismissKeyboard(&state)
    state.quoteFetching = false
    state.quote = nil
    state.allowance = DexMain.State.Allowance()
    state.confirmation?.newQuote = DexConfirmation.State.Quote(quote: nil)
}

private func clearDuringTyping(with state: inout DexMain.State) {
    state.quoteFetching = false
    state.quote = nil
    state.confirmation?.newQuote = DexConfirmation.State.Quote(quote: nil)
}

private func dismissKeyboard(_ state: inout DexMain.State) {
    state.source.textFieldIsFocused = false
    state.destination.textFieldIsFocused = false
}

private func makeSourceActive(with state: inout DexMain.State) {
    guard state.source.isCurrentInput.isNo else {
        return
    }
    state.source.isCurrentInput = true
    state.destination.isCurrentInput = false
    clearDuringTyping(with: &state)
    state.destination.inputText = ""
    state.destination.overrideAmount = nil
}

private func makeDestinationActive(with state: inout DexMain.State) {
    guard state.destination.isCurrentInput.isNo else {
        return
    }
    state.source.isCurrentInput = false
    state.destination.isCurrentInput = true
    clearDuringTyping(with: &state)
    state.source.inputText = ""
    state.source.overrideAmount = nil
}

private func flipBalances(with state: inout DexMain.State) {
    let source = state.source.balance
    let sourcePrice = state.source.price

    let destination = state.destination.balance
    let destinationPrice = state.destination.price

    state.source.inputText = ""
    state.source.balance = destination
    state.source.price = destinationPrice
    state.source.overrideAmount = nil
    state.source.isCurrentInput = false

    state.destination.inputText = ""
    state.destination.balance = source
    state.destination.price = sourcePrice
    state.destination.overrideAmount = nil
    state.destination.isCurrentInput = false
}

extension DexMain {
    enum CancellationID {
        case balances
        case quoteDebounce
        case quoteFetch
        case allowanceFetch
        case networkPrice
    }
}

private func dexInProgressDialog(quote: DexQuoteOutput) -> DexDialog {
    DexDialog(
        title: String(
            format: L10n.Execution.InProgress.title,
            quote.sellAmount.displayCode,
            quote.buyAmount.amount.displayCode
        ),
        status: .pending
    )
}

private func dexSuccessDialog(
    quote: DexQuoteOutput,
    transactionId: String
) -> DexDialog {
    DexDialog(
        title: String(
            format: L10n.Execution.Success.title,
            quote.sellAmount.displayCode,
            quote.buyAmount.amount.displayCode
        ),
        message: L10n.Execution.Success.body,
        buttons: [
            DexDialog.Button(
                title: "View on Explorer",
                action: .openURL(explorerURL(quote: quote, transactionId: transactionId))
            ),
            DexDialog.Button(
                title: "Done",
                action: .dismiss
            )
        ],
        status: .pending
    )
}

private func explorerURL(
    quote: DexQuoteOutput,
    transactionId: String,
    currenciesService: EnabledCurrenciesServiceAPI = EnabledCurrenciesService.default
) -> URL? {
    guard let network = currenciesService.network(for: quote.sellAmount.currency) else {
        return nil
    }
    return URL(string: network.networkConfig.explorerUrl + "/" + transactionId)
}

private func preselectNetwork(
    app: AppProtocol,
    from networks: [EVMNetwork],
    currenciesService: EnabledCurrenciesServiceAPI = EnabledCurrenciesService.default
) -> EVMNetwork? {
    if let currency = getThatCurrency(app: app),
       let network = currency.network(currenciesService: currenciesService),
       networks.contains(network)
    {
        return network
    }
    return networks
        .first(where: { $0.networkConfig == .ethereum }) ?? networks.first
}

func getThatCurrency(app: AppProtocol) -> CryptoCurrency? {
    if let source = getThatSourceCurrency(app: app) {
        eraseThatDestinationCurrency(app: app)
        return source
    }
    if let destination = getThatDestinationCurrency(app: app) {
        eraseThatSourceCurrency(app: app)
        return destination
    }
    return nil
}

func getThatSourceCurrency(app: AppProtocol) -> CryptoCurrency? {
    app.state.get(
        blockchain.ux.currency.exchange.dex.action.select.currency.source,
        as: CryptoCurrency?.self,
        or: nil
    )
}

func getThatDestinationCurrency(app: AppProtocol) -> CryptoCurrency? {
    app.state.get(
        blockchain.ux.currency.exchange.dex.action.select.currency.destination,
        as: CryptoCurrency?.self,
        or: nil
    )
}

func eraseThatCurrency(app: AppProtocol) {
    eraseThatSourceCurrency(app: app)
    eraseThatDestinationCurrency(app: app)
}

func eraseThatSourceCurrency(app: AppProtocol) {
    app.state.set(
        blockchain.ux.currency.exchange.dex.action.select.currency.source,
        to: nil
    )
}

func eraseThatDestinationCurrency(app: AppProtocol) {
    app.state.set(
        blockchain.ux.currency.exchange.dex.action.select.currency.destination,
        to: nil
    )
}
