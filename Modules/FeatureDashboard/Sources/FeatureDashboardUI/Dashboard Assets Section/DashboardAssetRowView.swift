// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainUI
import ComposableArchitecture
import DIKit
import FeatureDashboardDomain
import SwiftUI

struct DashboardAssetRowView: View {

    @BlockchainApp var app
    let store: StoreOf<DashboardAssetRow>

    init(store: StoreOf<DashboardAssetRow>) {
        self.store = store
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            Group {
                if let balance = viewStore.asset.balance {
                    balance.rowView(
                        viewStore.type.isCustodial ? .delta : .quote,
                        byline: {
                            if viewStore.type == .nonCustodial {
                                viewStore.asset.networkTag
                            }
                        }
                    )
                    .onTapGesture {
                        if viewStore.type == .fiat {
                            app.post(
                                event: blockchain.ux.dashboard.fiat.account.tap,
                                context: [
                                    blockchain.ux.dashboard.fiat.account.action.sheet.asset.id: viewStore.asset.currency.code,
                                    blockchain.ux.dashboard.fiat.account.action.sheet.asset: viewStore.asset,
                                    blockchain.ui.type.action.then.enter.into.detents: [
                                        blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                                    ]
                                ]
                            )
                        } else {
                            app.post(
                                event: blockchain.ux.dashboard.asset[viewStore.asset.currency.code].paragraph.row.tap,
                                context: [blockchain.ux.asset.select.origin: "DASHBOARD"]
                            )
                        }
                    }
                }
                if viewStore.isLastRow == false {
                    PrimaryDivider()
                }
            }
            .batch {
                set(
                    blockchain.ux.dashboard.asset[viewStore.asset.currency.code].paragraph.row.tap.then.enter.into,
                    to: blockchain.ux.asset[viewStore.asset.currency.code]
                )
                set(
                    blockchain.ux.dashboard.fiat.account.tap.then.enter.into,
                    to: blockchain.ux.dashboard.fiat.account.action.sheet
                )
            }
        })
    }
}

struct DashboardAssetRowView_Previews: PreviewProvider {
    static var previews: some View {
        let assetBalanceInfo = AssetBalanceInfo(
            cryptoBalance: .one(currency: .USD),
            fiatBalance: nil,
            currency: .crypto(.bitcoin),
            delta: nil,
            rawQuote: nil
        )
        DashboardAssetRowView(
            store: Store(
                initialState: DashboardAssetRow.State(
                    type: .custodial,
                    isLastRow: false,
                    asset: assetBalanceInfo
                ),
                reducer: { DashboardAssetRow(app: resolve()) }
            )
        )
    }
}

extension AssetBalanceInfo {
    @ViewBuilder
    fileprivate var networkTag: some View {
        if let network, let evm = network.evmNetwork {
            TagView(
                text: evm.networkConfig.shortName,
                variant: .outline
            )
        }
    }
}
