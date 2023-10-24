// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import Collections
import ComposableArchitecture
import ComposableArchitectureExtensions
import DIKit
import FeatureDashboardDomain
import FeatureDashboardUI
import FeatureProductsDomain
import Foundation
import MoneyKit
import SwiftUI

struct SuperAppContent: Reducer {
    @Dependency(\.totalBalanceService) var totalBalanceService
    let app: AppProtocol

    struct State: Equatable {
        var headerState: SuperAppHeader.State = .init()
        var externalTrading: DashboardContent.State = .init(appMode: .trading)
        var trading: DashboardContent.State = .init(appMode: .trading)
        var defi: DashboardContent.State = .init(appMode: .pkw)
        var appMode: AppMode
    }

    enum Action {
        case onAppear
        case onDisappear
        case refresh
        case onTotalBalanceFetched(TaskResult<TotalBalanceInfo>)
        case onTradingModeEnabledFetched(Bool)
        case onAppModeFetched(AppMode)
        case header(SuperAppHeader.Action)
        case trading(DashboardContent.Action)
        case externalTrading(DashboardContent.Action)
        case defi(DashboardContent.Action)
    }

    private struct TotalBalanceFetchId: Hashable {}

    var body: some Reducer<State, Action> {
        Scope(state: \State.headerState, action: /Action.header) { () -> SuperAppHeader in
            SuperAppHeader()
        }

        Scope(state: \.externalTrading, action: /Action.externalTrading) { () -> DashboardContent in
            DashboardContent()
        }

        Scope(state: \.trading, action: /Action.trading) { () -> DashboardContent in
            DashboardContent()
        }

        Scope(state: \.defi, action: /Action.defi) { () -> DashboardContent in
            DashboardContent()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                app.state.set(blockchain.app.is.ready.for.deep_link, to: true)
                return .merge(
                    .run { send in
                        for await isDeFiOnly in app.stream(blockchain.app.is.DeFi.only, as: Bool.self) {
                            await send(.onTradingModeEnabledFetched(isDeFiOnly.value?.not ?? true))
                        }
                    },
                    .run { send in
                        await send(.onAppModeFetched( await app.mode()))
                    })
            case .refresh:
                NotificationCenter.default.post(name: .dashboardPullToRefresh, object: nil)
                app.post(event: blockchain.ux.home.event.did.pull.to.refresh)
                state.headerState.isRefreshing = true
                return .run { [totalBalanceService] send in
                    for await total in totalBalanceService.totalBalance() {
                        await send(.onTotalBalanceFetched(TaskResult { try total.get() }))
                    }
                }
                .cancellable(id: TotalBalanceFetchId(), cancelInFlight: true)

            case .onTotalBalanceFetched(.success(let info)):
                state.headerState.totalBalance = info.total
                state.headerState.isRefreshing = false
                state.headerState.hasError = false
                return .none

            case .onTotalBalanceFetched(.failure):
                state.headerState.isRefreshing = false
                state.headerState.hasError = true
                return .none
            case .onDisappear:
                app.state.set(blockchain.app.is.ready.for.deep_link, to: false)
                return .none
            case .header:
                return .none
            case .trading:
                return .none
            case .defi:
                return .none
            case .externalTrading:
                return .none

            case .onTradingModeEnabledFetched(let enabled):
                state.headerState.tradingEnabled = enabled
                return .none

            case .onAppModeFetched(let appMode):
                state.appMode = appMode
                return .none
            }
        }
    }
}
