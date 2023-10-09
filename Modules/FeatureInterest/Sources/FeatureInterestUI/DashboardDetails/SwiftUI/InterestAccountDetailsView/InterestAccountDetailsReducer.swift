// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import ComposableArchitecture
import DIKit
import FeatureInterestDomain
import MoneyKit
import PlatformKit

struct InterestAccountDetailsReducer: ReducerProtocol {
    
    typealias State = InterestAccountDetailsState
    typealias Action = InterestAccountDetailsAction

    let fiatCurrencyService: FiatCurrencyServiceAPI
    let blockchainAccountRepository: BlockchainAccountRepositoryAPI
    let priceService: PriceServiceAPI
    let mainQueue: AnySchedulerOf<DispatchQueue>

    init(
        fiatCurrencyService: FiatCurrencyServiceAPI = resolve(),
        blockchainAccountRepository: BlockchainAccountRepositoryAPI = resolve(),
        priceService: PriceServiceAPI = resolve(),
        mainQueue: AnySchedulerOf<DispatchQueue> = .main
    ) {
        self.fiatCurrencyService = fiatCurrencyService
        self.blockchainAccountRepository = blockchainAccountRepository
        self.priceService = priceService
        self.mainQueue = mainQueue
    }

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadInterestAccountBalanceInfo:
                state.isLoading = true
                let priceService = priceService
                let overview = state.interestAccountOverview
                let balance = overview.balance
                let currency = overview.currency
                return fiatCurrencyService
                    .displayCurrencyPublisher
                    .flatMap { [priceService] fiatCurrency -> AnyPublisher<PriceQuoteAtTime, Error> in
                        priceService
                            .price(
                                of: currency,
                                in: fiatCurrency
                            )
                            .eraseError()
                    }
                    .map(\.moneyValue)
                    .map { moneyValue -> MoneyValue in
                        balance.convert(using: moneyValue)
                    }
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map { result in
                        switch result {
                        case .success(let amount):
                            return .interestAccountFiatBalanceFetched(amount)
                        case .failure:
                            return .interestAccountFiatBalanceFetchFailed
                        }
                    }
            case .loadSupportedActions:
                let account = blockchainAccountRepository
                    .accountWithCurrencyType(
                        state.interestAccountOverview.currency,
                        accountType: .custodial(.savings)
                    )
                    .compactMap { $0 as? CryptoInterestAccount }

                let canTransfer = account
                    .flatMap { interestAccount in
                        blockchainAccountRepository
                            .accountsAvailableToPerformAction(
                                .interestTransfer,
                                target: interestAccount as BlockchainAccount
                            )
                            .map { accounts in
                                accounts.contains(where: { $0.currencyType == interestAccount.currencyType })
                            }
                            .replaceError(with: false)
                    }

                let canWithdraw = account
                    .flatMap {
                        $0.can(perform: .interestWithdraw)
                            .replaceError(with: false)
                    }

                return Publishers
                    .Zip(
                        canTransfer,
                        canWithdraw
                    )
                    .receive(on: mainQueue)
                    .map { isTransferAvailable, isWithdrawAvailable -> [AssetAction] in
                        var actions: [AssetAction] = []
                        if isWithdrawAvailable {
                            actions.append(.interestWithdraw)
                        }
                        if isTransferAvailable {
                            actions.append(.interestTransfer)
                        }
                        return actions
                    }
                    .replaceError(with: [])
                    .eraseToEffect()
                    .map { actions -> InterestAccountDetailsAction in
                        .interestAccountActionsFetched(actions)
                    }
            case .interestAccountActionsFetched(let actions):
                state.supportedActions = actions
                state.isLoading = false
                return .none
            case .interestAccountFiatBalanceFetchFailed:
                // TODO: Improve this
                state.isLoading = false
                state.interestAccountBalanceSummary = .init(
                    currency: state.interestAccountOverview.currency,
                    cryptoBalance: state.interestAccountOverview.balance.displayString,
                    fiatBalance: "Unknown"
                )
                return EffectTask(value: .loadSupportedActions)
            case .interestAccountFiatBalanceFetched(let moneyValue):
                state.interestAccountBalanceSummary = .init(
                    currency: state.interestAccountOverview.currency,
                    cryptoBalance: state.interestAccountOverview.balance.displayString,
                    fiatBalance: moneyValue.displayString
                )
                return EffectTask(value: .loadSupportedActions)
            case .interestTransferTapped:
                state.interestAccountActionSelection = .init(
                    currency: state.interestAccountOverview.currency,
                    action: .interestTransfer
                )
                return EffectTask(value: .dismissInterestDetailsScreen)
            case .interestWithdrawTapped:
                state.interestAccountActionSelection = .init(
                    currency: state.interestAccountOverview.currency,
                    action: .interestWithdraw
                )
                return EffectTask(value: .dismissInterestDetailsScreen)
            case .loadCryptoInterestAccount,
                 .closeButtonTapped,
                 .interestAccountDescriptorTapped,
                 .dismissInterestDetailsScreen:
                return .none
            }
        }
    }
}
