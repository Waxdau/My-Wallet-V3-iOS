// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import ComposableArchitecture
import FeatureDexDomain
import Foundation
import MoneyKit

struct NetworkPicker: Reducer {
    @Dependency(\.dexService) var dexService
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.app) var app

    private var tag = blockchain.ux.currency.exchange.dex.network.picker

    struct State: Equatable {
        init(currentNetwork: String? = nil) {
            self.currentNetwork = currentNetwork
        }

        var availableNetworks: [EVMNetwork] = []
        var currentNetwork: String?
    }

    enum Action: Equatable {
        case onAppear
        case onNetworkSelected(EVMNetwork)
        case onDismiss
        case onAvailableNetworksFetched([EVMNetwork])
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .publisher {
                    dexService.availableChainsService
                        .availableEvmChains()
                        .replaceError(with: [])
                        .receive(on: mainQueue)
                        .map(Action.onAvailableNetworksFetched)
                }

            case .onAvailableNetworksFetched(let networks):
                state.availableNetworks = networks
                return .none

            case .onNetworkSelected(let network):
                state.currentNetwork = network.networkConfig.networkTicker
                return .run { _ in
                    try await app.set(
                        tag.selected.network.ticker.value,
                        to: network.networkConfig.networkTicker
                    )
                    try await app.set(
                        tag.selected.network.ticker.entry.paragraph.row.tap.then.close,
                        to: true
                    )
                    app.post(
                        event: tag.selected.network.ticker.entry.paragraph.row.tap
                    )
                }
            case .onDismiss:
                return .run { _ in
                    try await app.set(
                        tag.selected.network.ticker.article.plain.navigation.bar.button.close.tap.then.close,
                        to: true
                    )
                    app.post(event: tag.selected.network.ticker.article.plain.navigation.bar.button.close.tap)
                }
            }
        }
    }
}
