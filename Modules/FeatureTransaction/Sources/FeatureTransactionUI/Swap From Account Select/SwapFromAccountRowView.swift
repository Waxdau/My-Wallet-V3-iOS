// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainUI
import ComposableArchitecture
import DIKit
import SwiftUI

struct SwapFromAccountRowView: View {
    @BlockchainApp var app
    let store: StoreOf<SwapFromAccountRow>
    @ObservedObject var viewStore: ViewStore<SwapFromAccountRow.State, SwapFromAccountRow.Action>
    init(store: StoreOf<SwapFromAccountRow>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            SimpleBalanceRow(
                leadingTitle: viewStore.leadingTitle,
                trailingTitle: viewStore.trailingTitle,
                trailingDescription: viewStore.trailingDescriptionString,
                trailingDescriptionColor: viewStore.trailingDescriptionColor,
                inlineTagView: viewStore.networkTag,
                action: {
                    viewStore.send(.onAccountSelected)
                },
                leading: {
                    viewStore.currency?.logo()
                }
            )

            if viewStore.isLastRow == false {
                PrimaryDivider()
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        .bindings {
            subscribe(viewStore.$balance, to: blockchain.coin.core.account[viewStore.accountId].balance.total)
            subscribe(viewStore.$networkLogo, to: blockchain.coin.core.account[viewStore.accountId].network.logo)
            subscribe(viewStore.$networkName, to: blockchain.coin.core.account[viewStore.accountId].network.name)
        }
        .bindings {
            if let currency = viewStore.currency {
                subscribe(viewStore.$price, to: blockchain.api.nabu.gateway.price.crypto[currency.code].fiat.quote.value)
            }
        }
    }
}
