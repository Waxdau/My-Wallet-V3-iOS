// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import Combine
import ComposableArchitecture
import ComposableArchitectureExtensions
import DIKit
import FeatureDashboardDomain
import FeatureWithdrawalLocksDomain
import Foundation
import MoneyKit
import SwiftUI
import ToolKit

public struct DashboardAssetsSection: Reducer {
    public let assetBalanceInfoRepository: AssetBalanceInfoRepositoryAPI
    public let withdrawalLocksRepository: WithdrawalLocksRepositoryAPI
    public let app: AppProtocol
    public init(
        assetBalanceInfoRepository: AssetBalanceInfoRepositoryAPI,
        withdrawalLocksRepository: WithdrawalLocksRepositoryAPI,
        app: AppProtocol
    ) {
        self.assetBalanceInfoRepository = assetBalanceInfoRepository
        self.withdrawalLocksRepository = withdrawalLocksRepository
        self.app = app
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case refresh
        case onBalancesFetched(Result<[AssetBalanceInfo], Never>)
        case displayAssetBalances([AssetBalanceInfo])
        case onFiatBalanceFetched(Result<FiatBalancesInfo, Never>)
        case onWithdrawalLocksFetched(Result<WithdrawalLocks, Never>)
        case onAllAssetsTapped
        case assetRowTapped(
            id: DashboardAssetRow.State.ID,
            action: DashboardAssetRow.Action
        )

        case fiatAssetRowTapped(
            id: DashboardAssetRow.State.ID,
            action: DashboardAssetRow.Action
        )
    }

    public struct State: Equatable {
        @BindingState var isWalletActionSheetShown = false
        var isLoading: Bool = false
        var fiatAssetInfo: [AssetBalanceInfo] = []
        let presentedAssetsType: PresentedAssetType
        var assetRows: IdentifiedArrayOf<DashboardAssetRow.State> = []
        var fiatAssetRows: IdentifiedArrayOf<DashboardAssetRow.State> = []
        var withdrawalLocks: WithdrawalLocks?
        /// `true` if requests failing
        var failedLoadingBalances: Bool = false
        /// An array of failing networks as per backend
        var balancesFailingForNetworks: [AssetBalanceInfoNetwork]?
        @BindingState var alertCardSeen = false

        var seeAllButtonHidden = true

        var balancesFailingForNetworksTitles: String? {
            balancesFailingForNetworks?.map(\.networkOrAssetName).joined(separator: ", ")
        }

        public init(presentedAssetsType: PresentedAssetType) {
            self.presentedAssetsType = presentedAssetsType
        }
    }

    private enum CancellationID {
        case blockchainAssets
        case deFiAssets
        case fiatAssets
        case onHoldAssets
        case smallBalances
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = state.assetRows.isEmpty

                let refreshEvents = app.on(blockchain.ux.home.event.did.pull.to.refresh).mapToVoid().prepend(())
                    .combineLatest(app.on(blockchain.ux.transaction.event.did.finish).mapToVoid().prepend(()))
                    .mapToVoid()

                let cryptoEffect = Effect.publisher { [state] in
                    app.publisher(for: blockchain.user.currency.preferred.fiat.display.currency, as: FiatCurrency.self)
                        .compactMap(\.value)
                        .combineLatest(refreshEvents)
                        .flatMap { [state, assetBalanceInfoRepository] fiatCurrency, _ -> StreamOf<[AssetBalanceInfo], Never> in
                            let cryptoPublisher = state.presentedAssetsType.isCustodial
                            ? assetBalanceInfoRepository.cryptoCustodial(fiatCurrency: fiatCurrency, time: .now)
                            : assetBalanceInfoRepository.cryptoNonCustodial(fiatCurrency: fiatCurrency, time: .now)
                            return cryptoPublisher
                        }
                        .receive(on: DispatchQueue.main)
                        .map(Action.onBalancesFetched)
                }
                .cancellable(
                    id: state.presentedAssetsType.isCustodial ? CancellationID.blockchainAssets : CancellationID.deFiAssets,
                    cancelInFlight: true
                )

                let fiatEffect = Effect.publisher {
                    app.publisher(for: blockchain.user.currency.preferred.fiat.display.currency, as: FiatCurrency.self)
                        .compactMap(\.value)
                        .combineLatest(
                            app.publisher(for: blockchain.user.currency.preferred.fiat.trading.currency, as: FiatCurrency.self).compactMap(\.value),
                            refreshEvents
                        )
                        .flatMap { [assetBalanceInfoRepository] fiatCurrency, tradingCurrency, _ -> StreamOf<FiatBalancesInfo, Never> in
                            assetBalanceInfoRepository
                                .fiat(fiatCurrency: fiatCurrency, time: .now)
                                .map { $0.map { FiatBalancesInfo(balances: $0, tradingCurrency: tradingCurrency) } }
                                .eraseToAnyPublisher()
                        }
                        .receive(on: DispatchQueue.main)
                        .map(Action.onFiatBalanceFetched)
                }
                .cancellable(id: CancellationID.fiatAssets, cancelInFlight: true)

                let onHoldEffect = Effect.publisher { [state] in
                    app.publisher(
                        for: blockchain.user.currency.preferred.fiat.display.currency,
                        as: FiatCurrency.self
                    )
                        .compactMap(\.value)
                        .combineLatest(refreshEvents)
                        .flatMap { [state, withdrawalLocksRepository] fiatCurrency, _ -> StreamOf<WithdrawalLocks, Never> in
                            guard state.presentedAssetsType == .custodial else {
                                return .empty()
                            }
                            return withdrawalLocksRepository
                                .withdrawalLocks(currencyCode: fiatCurrency.code)
                                .result()
                        }
                        .receive(on: DispatchQueue.main)
                        .map(Action.onWithdrawalLocksFetched)
                }
                .cancellable(id: CancellationID.onHoldAssets, cancelInFlight: true)

                guard state.presentedAssetsType == .custodial else {
                    return cryptoEffect
                }
                return .merge(
                    cryptoEffect,
                    fiatEffect,
                    onHoldEffect
                )
            case .onBalancesFetched(.success(let balanceInfo)):
                state.failedLoadingBalances = false
                state.isLoading = false
                state.seeAllButtonHidden = balanceInfo.isEmpty
                state.alertCardSeen = false
                state.balancesFailingForNetworks = balanceInfo
                    .filter { $0.balanceFailingForNetwork ?? false }
                    .compactMap(\.network)
                    .unique

                return .publisher { [state] in
                    app
                        .publisher(for: state.presentedAssetsType.smallBalanceFilterTag)
                        .map { value in
                            let filterIsOn = value.value ?? false
                            let allBalances = balanceInfo
                                .filter { $0.balance?.hasPositiveDisplayableBalance ?? false }
                            if filterIsOn {
                                return allBalances
                            } else {
                                let bigBalances = allBalances.filter(\.hasBalance)
                                return bigBalances.isEmpty ? allBalances : bigBalances
                            }
                        }
                        .map(Action.displayAssetBalances)
                }
                .cancellable(id: CancellationID.smallBalances, cancelInFlight: true)

            case .onBalancesFetched(.failure):
                state.isLoading = false
                state.failedLoadingBalances = true
                return .none

            case .onFiatBalanceFetched(.success(let fiatBalancesInfo)):
                let filteredBalances = fiatBalancesInfo.balances.filter { info in
                    guard info.currency == fiatBalancesInfo.tradingCurrency.currencyType else {
                        return info.balance?.hasPositiveDisplayableBalance ?? false
                    }
                    return true
                }
                state.fiatAssetRows = IdentifiedArrayOf(uniqueElements: Array(filteredBalances).map {
                    DashboardAssetRow.State(
                        type: .fiat,
                        isLastRow: $0.id == filteredBalances.last?.id,
                        asset: $0
                    )
                })

                return .none

            case .displayAssetBalances(let balanceInfo):
                let displayableElements = Array(balanceInfo).prefix(state.presentedAssetsType.assetDisplayLimit)
                let elements = displayableElements
                    .map {
                        DashboardAssetRow.State(
                            type: state.presentedAssetsType.rowType,
                            isLastRow: $0.id == displayableElements.last?.id,
                            asset: $0
                        )
                    }
                state.assetRows = IdentifiedArrayOf(uniqueElements: elements)
                return .none

            case .onFiatBalanceFetched(.failure):
                return .none

            case .onWithdrawalLocksFetched(.success(let withdrawalLocks)):
                state.withdrawalLocks = withdrawalLocks
                return .none

            case .onWithdrawalLocksFetched(.failure):
                return .none

            case .refresh:
                state.isLoading = true
                return .none

            case .assetRowTapped:
                return .none

            case .onAllAssetsTapped:
                return .none

            case .fiatAssetRowTapped:
                return .none

            case .binding:
                return .none
            }
        }
        .forEach(\.assetRows, action: /Action.assetRowTapped) {
            DashboardAssetRow(app: app)
        }
        .forEach(\.fiatAssetRows, action: /Action.fiatAssetRowTapped) {
            DashboardAssetRow(app: app)
        }
    }
}
