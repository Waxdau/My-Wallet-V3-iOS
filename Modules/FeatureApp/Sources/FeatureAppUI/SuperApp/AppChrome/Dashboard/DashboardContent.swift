// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import Collections
import ComposableArchitecture
import DelegatedSelfCustodyDomain
import DIKit
import FeatureDashboardUI
import FeatureDexUI
import FeatureProductsDomain

struct ExternalTradingTabsState: Equatable {
    var selectedTab: Tag.Reference = blockchain.ux.user.external.portfolio[].reference
    var home: ExternalTradingDashboard.State = .init()
    var prices: PricesScene.State = .init(
        appMode: .trading,
        topMoversState: nil
    )
}

struct TradingTabsState: Equatable {
    var selectedTab: Tag.Reference = blockchain.ux.user.portfolio[].reference

    var home: TradingDashboard.State = .init()
    var prices: PricesScene.State = .init(appMode: .trading, topMoversState: .init(.init(presenter: .prices)))
}

struct DefiTabsState: Equatable {
    var selectedTab: Tag.Reference = blockchain.ux.user.portfolio[].reference

    var home: DeFiDashboard.State = .init()
    var prices: PricesScene.State = .init(appMode: .pkw)
    var dex: DexDashboard.State = .init()
}

struct DashboardContent: Reducer {
    @Dependency(\.app) var app

    struct State: Equatable {
        let appMode: AppMode
        var tabs: OrderedSet<Tab>?
        var selectedTab: Tag.Reference {
            switch appMode {
            case .pkw:
                return defiState.selectedTab
            case .trading:
                return tradingState.selectedTab
            }
        }

        // Tabs
        var tradingState: TradingTabsState = .init()
        var externalTradingState: ExternalTradingTabsState = .init()
        var defiState: DefiTabsState = .init()
    }

    enum Action {
        case onAppear
        case tabs(OrderedSet<Tab>?)
        case select(Tag.Reference)
        // Tabs
        case externalTradingHome(ExternalTradingDashboard.Action)
        case tradingHome(TradingDashboard.Action)
        case defiHome(DeFiDashboard.Action)
        case tradingPrices(PricesScene.Action)
        case defiPrices(PricesScene.Action)
        case externalTradingPrices(PricesScene.Action)

        case defiDex(DexDashboard.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \State.externalTradingState.home, action: /Action.externalTradingHome) { () -> ExternalTradingDashboard in
            ExternalTradingDashboard(
                app: app,
                assetBalanceInfoRepository: DIKit.resolve(),
                activityRepository: DIKit.resolve(),
                custodialActivityRepository: DIKit.resolve(),
                withdrawalLocksRepository: DIKit.resolve()
            )
        }

        Scope(state: \State.tradingState.home, action: /Action.tradingHome) { () -> TradingDashboard in
            // TODO: DO NOT rely on DIKit...
            TradingDashboard(
                app: app,
                assetBalanceInfoRepository: DIKit.resolve(),
                activityRepository: DIKit.resolve(),
                custodialActivityRepository: DIKit.resolve(),
                withdrawalLocksRepository: DIKit.resolve()
            )
        }
        Scope(state: \.defiState.home, action: /Action.defiHome) { () -> DeFiDashboard in
            DeFiDashboard(
                app: app,
                assetBalanceInfoRepository: DIKit.resolve(),
                activityRepository: DIKit.resolve(),
                withdrawalLocksRepository: DIKit.resolve()
            )
        }
        Scope(state: \.tradingState.prices, action: /Action.tradingPrices) { () -> PricesScene in
            PricesScene(
                app: app,
                enabledCurrencies: DIKit.resolve(),
                topMoversService: DIKit.resolve(),
                watchlistService: DIKit.resolve()
            )
        }

        Scope(state: \.externalTradingState.prices, action: /Action.externalTradingPrices) { () -> PricesScene in
            PricesScene(
                app: app,
                enabledCurrencies: DIKit.resolve(),
                topMoversService: DIKit.resolve(),
                watchlistService: DIKit.resolve()
            )
        }

        Scope(state: \.defiState.prices, action: /Action.defiPrices) { () -> PricesScene in
            PricesScene(
                app: app,
                enabledCurrencies: DIKit.resolve(),
                topMoversService: DIKit.resolve(),
                watchlistService: DIKit.resolve()
            )
        }
        Scope(state: \.defiState.dex, action: /Action.defiDex) { () -> DexDashboard in
            DexDashboard(analyticsRecorder: DIKit.resolve())
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [state] send in
                    switch state.appMode {
                    case .trading:
                        let stream = app.stream(blockchain.app.is.external.brokerage, as: Bool.self).flatMap { externalTradingEnabled in
                            if externalTradingEnabled.value == true {
                                return app.stream(blockchain.app.configuration.superapp.external.brokerage.tabs, as: TabConfig.self)
                            } else {
                                return app.stream(blockchain.app.configuration.superapp.brokerage.tabs, as: TabConfig.self)
                            }
                        }

                        for await event in stream {
                            await send(DashboardContent.Action.tabs(event.value?.tabs))
                        }
                    case .pkw:
                        for await event in app.stream(blockchain.app.configuration.superapp.defi.tabs, as: TabConfig.self) {
                            await send(DashboardContent.Action.tabs(event.value?.tabs))
                        }
                    }
                }
            case .tabs(let tabs):
                state.tabs = tabs
                return .none
            case .select(let tag):
                switch state.appMode {
                case .trading:
                    state.tradingState.selectedTab = tag
                case .pkw:
                    state.defiState.selectedTab = tag
                }
                return .none
            case .tradingHome, .defiHome, .externalTradingHome:
                return .none
            case .tradingPrices, .defiPrices, .externalTradingPrices:
                return .none
            case .defiDex:
                return .none
            }
        }
    }
}
