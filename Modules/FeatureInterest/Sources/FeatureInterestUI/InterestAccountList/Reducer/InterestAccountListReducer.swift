// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import Combine
import ComposableArchitecture
import FeatureInterestDomain
import MoneyKit
import PlatformKit
import ToolKit

struct TransactionFetchIdentifier: Hashable {}

struct InterestAccountListReducer: ReducerProtocol {
    
    typealias State = InterestAccountListState
    typealias Action = InterestAccountListAction

    let environment: InterestAccountSelectionEnvironment

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .didReceiveInterestAccountResponse(let response):
                switch response {
                case .success(let accountOverviews):
                    let details: [InterestAccountDetails] = accountOverviews.map {
                        .init(
                            ineligibilityReason: $0.ineligibilityReason,
                            currency: $0.currency,
                            balance: $0.balance,
                            interestEarned: $0.totalEarned,
                            rate: $0.interestAccountRate.rate
                        )
                    }
                    .sorted { $0.balance.isPositive && !$1.balance.isPositive }

                    state.interestAccountOverviews = accountOverviews
                    state.interestAccountDetails = .init(uniqueElements: details)
                    state.loadingStatus = .loaded
                case .failure(let error):
                    state.loadingStatus = .loaded
                    Logger.shared.error(error)
                }
                return .none

            case .setupInterestAccountListScreen:
                if state.loadingStatus == .loaded {
                    return .none
                }
                state.loadingStatus = .fetchingAccountStatus
                return environment
                    .kycVerificationService
                    .isKYCVerified
                    .receive(on: environment.mainQueue)
                    .eraseToEffect()
                    .map { result in
                        .didReceiveKYCVerificationResponse(result)
                    }
            case .didReceiveKYCVerificationResponse(let value):
                state.isKYCVerified = value
                return EffectTask(value: .loadInterestAccounts)
            case .loadInterestAccounts:
                state.loadingStatus = .fetchingRewardsAccounts
                return environment
                    .fiatCurrencyService
                    .displayCurrencyPublisher
                    .flatMap { [environment] fiatCurrency in
                        environment
                            .accountOverviewRepository
                            .fetchInterestAccountOverviewListForFiatCurrency(fiatCurrency)
                    }
                    .receive(on: environment.mainQueue)
                    .catchToEffect()
                    .map { result in
                        .didReceiveInterestAccountResponse(result)
                    }

            case .interestAccountButtonTapped(let selected, let action):
                switch action {
                case .viewInterestButtonTapped:
                    guard let overview = state
                        .interestAccountOverviews
                        .first(where: { $0.id == selected.identity })
                    else {
                        fatalError("Expected an InterestAccountOverview")
                    }

                    state.interestAccountDetailsState = .init(interestAccountOverview: overview)
                    return .enter(into: .details, context: .none)
                case .earnInterestButtonTapped(let value):
                    let blockchainAccountRepository = environment.blockchainAccountRepository
                    let currency = value.currency

                    return Publishers.CombineLatest(
                        environment
                            .blockchainAccountRepository
                            .accountWithCurrencyType(
                                currency,
                                accountType: .custodial(.savings)
                            )
                            .compactMap { $0 as? CryptoInterestAccount },
                        environment
                            .blockchainAccountRepository
                            .accountWithCurrencyType(
                                currency,
                                accountType: .custodial(.trading)
                            )
                            .compactMap { $0 as? CryptoTradingAccount }
                    )
                        .flatMap { account, target -> AnyPublisher<(Bool, InterestTransactionState), Never> in
                            let availableAccounts = blockchainAccountRepository
                                .accountsAvailableToPerformAction(
                                    .interestTransfer,
                                    target: account
                                )
                                .map { $0.filter { $0.currencyType == account.currencyType } }
                                .map { !$0.isEmpty }
                                .replaceError(with: false)
                                .eraseToAnyPublisher()

                            let interestTransactionState = InterestTransactionState(
                                account: account,
                                target: target,
                                action: .interestTransfer
                            )

                            return Publishers.Zip(
                                availableAccounts,
                                Just(interestTransactionState)
                            )
                            .eraseToAnyPublisher()
                        }
                        .receive(on: environment.mainQueue)
                        .catchToEffect()
                        .map { values -> InterestAccountListAction in
                            guard let (areAccountsAvailable, transactionState) = values.success else {
                                impossible()
                            }
                            if areAccountsAvailable {
                                return .interestTransactionStateFetched(transactionState)
                            }

                            let ineligibleWalletsState = InterestNoEligibleWalletsState(
                                interestAccountRate: InterestAccountRate(
                                    currencyCode: currency.code,
                                    rate: value.rate
                                )
                            )
                            return .interestAccountIsWithoutEligibleWallets(ineligibleWalletsState)
                        }
                }
            case .interestAccountIsWithoutEligibleWallets(let ineligibleWalletsState):
                state.interestNoEligibleWalletsState = ineligibleWalletsState
                return .enter(into: .noWalletsError)
            case .interestAccountNoEligibleWallets(let action):
                switch action {
                case .startBuyTapped:
                    return .none
                case .dismissNoEligibleWalletsScreen:
                    return .dismiss()
                case .startBuyAfterDismissal(let cryptoCurrency):
                    state.loadingStatus = .fetchingRewardsAccounts
                    return EffectTask(value: .dismissAndLaunchBuy(cryptoCurrency))
                case .startBuyOnDismissalIfNeeded:
                    return .none
                }
            case .dismissAndLaunchBuy(let cryptoCurrency):
                state.buyCryptoCurrency = cryptoCurrency
                return .none
            case .interestTransactionStateFetched(let transactionState):
                state.interestTransactionState = transactionState
                let isTransfer = transactionState.action == .interestTransfer
                return EffectTask(
                    value:
                    isTransfer ? .startInterestTransfer(transactionState) : .startInterestWithdraw(transactionState)
                )
            case .startInterestWithdraw(let value):
                return environment
                    .blockchainAccountRepository
                    .accountWithCurrencyType(value.account.currencyType, accountType: .custodial(.trading))
                    .compactMap { $0 as? CryptoTradingAccount }
                    .flatMap { target in
                        environment
                            .transactionRouterAPI
                            .presentTransactionFlow(to: .interestWithdraw(value.account, target))
                    }
                    .catchToEffect()
                    .map { _ -> InterestAccountListAction in
                        .loadInterestAccounts
                    }
            case .startInterestTransfer(let value):
                return environment
                    .transactionRouterAPI
                    .presentTransactionFlow(to: .interestTransfer(value.account))
                    .catchToEffect()
                    .map { _ -> InterestAccountListAction in
                        .loadInterestAccounts
                    }
            case .route(let route):
                state.route = route
                return .none
            case .interestAccountDetails:
                return .none
            }
        }
        .ifLet(\.interestNoEligibleWalletsState, action: /Action.interestAccountNoEligibleWallets) {
            InterestNoEligibleWalletsReducer()
        }
        .ifLet(\.interestAccountDetailsState, action: /Action.interestAccountDetails) {
            InterestAccountDetailsReducer(
                fiatCurrencyService: environment.fiatCurrencyService,
                blockchainAccountRepository: environment.blockchainAccountRepository,
                priceService: environment.priceService,
                mainQueue: environment.mainQueue
            )
        }
        InterestReducerCore(environment: environment)
        InterestAnalytics(analyticsRecorder: environment.analyticsRecorder)
    }
}

struct InterestReducerCore: ReducerProtocol {
    
    typealias State = InterestAccountListState
    typealias Action = InterestAccountListAction
    
    let environment: InterestAccountSelectionEnvironment
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .interestAccountDetails(.dismissInterestDetailsScreen):
                return .dismiss()
            case .interestAccountDetails(.loadCryptoInterestAccount(isTransfer: let isTransfer, let currency)):
                return Publishers.CombineLatest(
                    environment
                        .blockchainAccountRepository
                        .accountWithCurrencyType(
                            currency,
                            accountType: .custodial(.savings)
                        )
                        .compactMap { $0 as? CryptoInterestAccount },
                    environment
                        .blockchainAccountRepository
                        .accountWithCurrencyType(
                            currency,
                            accountType: .custodial(.trading)
                        )
                        .compactMap { $0 as? CryptoTradingAccount }
                )
                .map { account, target in
                    InterestTransactionState(
                        account: account,
                        target: target,
                        action: isTransfer ? .interestTransfer : .interestWithdraw
                    )
                }
                .catchToEffect()
                .map { transactionState in
                    guard let value = transactionState.success else {
                        unimplemented()
                    }
                    return value
                }
                .map { transactionState -> InterestAccountListAction in
                        .interestTransactionStateFetched(transactionState)
                }
            default:
                return .none
            }
        }
    }
}

// MARK: - Analytics Extension

struct InterestAnalytics: ReducerProtocol {

    typealias State = InterestAccountListState
    typealias Action = InterestAccountListAction

    let analyticsRecorder: AnalyticsEventRecorderAPI

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .didReceiveInterestAccountResponse(.success):
                return .fireAndForget {
                    analyticsRecorder.record(
                        event: .interestViewed
                    )
                }
            case .interestAccountButtonTapped(_, .viewInterestButtonTapped(let details)):
                return .fireAndForget {
                    analyticsRecorder.record(
                        event: .walletRewardsDetailClicked(currency: details.currency.code)
                    )
                }
            case .interestAccountDetails(.interestAccountActionsFetched):
                return .fireAndForget { [state] in
                    let currencyCode = state.interestAccountDetailsState?.interestAccountOverview.currency.code
                    analyticsRecorder.record(
                        event: .walletRewardsDetailViewed(currency: currencyCode ?? "")
                    )
                }
            case .interestAccountButtonTapped(_, .earnInterestButtonTapped(let details)):
                return .fireAndForget {
                    analyticsRecorder.record(
                        event: .interestDepositClicked(currency: details.currency.code)
                    )
                }
            case .interestAccountDetails(.interestWithdrawTapped(let currency)):
                return .fireAndForget {
                    analyticsRecorder.record(
                        event: .interestWithdrawalClicked(currency: currency.code)
                    )
                }
            case .interestAccountDetails(.interestTransferTapped(let currency)):
                return .fireAndForget {
                    analyticsRecorder.record(
                        event: .walletRewardsDetailDepositClicked(currency: currency.code)
                    )
                }
            default:
                return .none
            }
        }
    }
}
