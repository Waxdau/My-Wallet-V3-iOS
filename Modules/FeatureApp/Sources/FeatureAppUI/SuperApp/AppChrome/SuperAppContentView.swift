// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import ComposableArchitecture
import DIKit
import FeatureDashboardUI
import FeatureProductsDomain
import SwiftUI

struct SuperAppContentView: View {
    @BlockchainApp var app
    let store: StoreOf<SuperAppContent>
    /// The current selected app mode
    @Binding var currentModeSelection: AppMode
    /// The content offset for the modal sheet
    @Binding var contentOffset: ModalSheetContext

    @State private var isDeFiOnly = true
    @State private var isExternalTradingEnabled = false
    private var isTradingEnabled: Bool { !isDeFiOnly }

    @State private var selectedDetent: UISheetPresentationController.Detent.Identifier = AppChromeDetents.collapsed.identifier
    /// `True` when a pull to refresh is triggered, otherwise `false`
    @Binding var isRefreshing: Bool

    @State private var hideBalanceAfterRefresh = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        WithViewStore(store, observe: \.headerState, content: { viewStore in
            SuperAppHeaderView(
                store: store.scope(state: \.headerState, action: SuperAppContent.Action.header),
                currentSelection: $currentModeSelection,
                contentOffset: $contentOffset,
                isRefreshing: $isRefreshing,
                headerFrame: .constant(.zero)
            )
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onDisappear {
                viewStore.send(.onDisappear)
            }
            .onAppear {
                app.post(value: currentModeSelection.rawValue, of: blockchain.app.mode)
                update(colorScheme: colorScheme)
            }
            .onChange(of: currentModeSelection) { newValue in
                app.post(value: newValue.rawValue, of: blockchain.app.mode)
            }
            .onChange(of: colorScheme) { newValue in
                update(colorScheme: newValue)
            }
            .onChange(of: isRefreshing) { newValue in
                if !newValue {
                    hideBalanceAfterRefresh.toggle()
                }
            }
            .bindings(
                managing: { update in
                    if case .didSynchronize = update, isDeFiOnly {
                        currentModeSelection = .pkw
                    }
                },
                {
                    subscribe($currentModeSelection.removeDuplicates().animation(), to: blockchain.app.mode)
                    subscribe($isDeFiOnly, to: blockchain.app.is.DeFi.only)
                    subscribe($isExternalTradingEnabled, to: blockchain.api.nabu.gateway.user.products.product["USE_EXTERNAL_TRADING_ACCOUNT"].is.eligible)
                }
            )
            .onChange(of: isTradingEnabled) { newValue in
                if currentModeSelection == .trading, newValue == false {
                    currentModeSelection = .pkw
                }
            }
            .task(id: hideBalanceAfterRefresh) {
                // run initial "animation" and select `semiCollapsed` detent after 3 second
                do {
                    try await Task.sleep(nanoseconds: 3 * 1000000000)
                    if !isRefreshing {
                        let detent: AppChromeDetents = viewStore.state.tradingEnabled ? .semiCollapsed : .expanded
                        selectedDetent = detent.identifier
                    }
                } catch {}
            }
            .refreshable {
                await viewStore.send(.refresh, while: \.isRefreshing)
            }
            .sheet(isPresented: .constant(true), content: {
                SuperAppDashboardContentView(
                    currentModeSelection: $currentModeSelection,
                    isTradingEnabled: isTradingEnabled,
                    isExternalTradingEnabled: isExternalTradingEnabled,
                    store: store
                )
                .background(
                    Color.semantic.light
                )
                .frame(maxWidth: .infinity)
                .presentationDetents(
                    selectedDetent: $selectedDetent,
                    largestUndimmedDetentIdentifier: largestUndimmedDetentIdentifier(isTradingEnabled: isTradingEnabled),
                    limitDetents: .constant(!isTradingEnabled),
                    modalOffset: $contentOffset
                )
            })
        })
    }

    private func update(colorScheme: ColorScheme) {
        let interface = blockchain.ui.device.settings.interface
        app.state.transaction { state in
            state.set(interface.style, to: colorScheme == .dark ? interface.style.dark[] : interface.style.light[])
            state.set(interface.is.dark, to: colorScheme == .dark)
            state.set(interface.is.light, to: colorScheme == .light)
        }
    }

    private func largestUndimmedDetentIdentifier(
        isTradingEnabled: Bool
    ) -> UISheetPresentationController.Detent.Identifier {
        isTradingEnabled ? AppChromeDetents.semiCollapsed.identifier : AppChromeDetents.expanded.identifier
    }
}
