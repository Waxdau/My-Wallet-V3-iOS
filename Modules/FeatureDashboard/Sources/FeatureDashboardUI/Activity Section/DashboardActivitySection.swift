// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AsyncAlgorithms
import BlockchainNamespace
import ComposableArchitecture
import ComposableArchitectureExtensions
import DIKit
import FeatureDashboardDomain
import MoneyKit
import SwiftUI
import UnifiedActivityDomain

public struct DashboardActivitySection: Reducer {
    enum ViewState {
        case idle
        case empty
        case data
        case loading
    }

    enum Constants {
        static var maxNumberOfActivityItems: Int { 5 }
    }

    public let app: AppProtocol
    public let activityRepository: UnifiedActivityRepositoryAPI
    public let custodialActivityRepository: CustodialActivityRepositoryAPI

    public init(
        app: AppProtocol,
        activityRepository: UnifiedActivityRepositoryAPI,
        custodialActivityRepository: CustodialActivityRepositoryAPI
    ) {
        self.app = app
        self.activityRepository = activityRepository
        self.custodialActivityRepository = custodialActivityRepository
    }

    public enum Action: Equatable {
        case onAppear
        case onActivityFetched(Result<[ActivityEntry], Never>)
        case onAllActivityTapped
        case onActivityRowTapped(
            id: DashboardActivityRow.State.ID,
            action: DashboardActivityRow.Action
        )
    }

    public struct State: Equatable {
        var isLoading: Bool = false
        var activityRows: IdentifiedArrayOf<DashboardActivityRow.State> = []
        let placeholderRows: IdentifiedArrayOf<DashboardActivityRow.State>
        let presentedAssetType: PresentedAssetType
        var viewState: ViewState = .idle
        public init(with presentedAssetType: PresentedAssetType) {
            self.presentedAssetType = presentedAssetType
            self.placeholderRows = providePlaceholderItems()
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.viewState = .loading
                if state.presentedAssetType.isCustodial {
                    return .publisher {
                        custodialActivityRepository
                            .activity()
                            .receive(on: DispatchQueue.main)
                            .map { .onActivityFetched($0) }
                    }
                } else {
                    return .publisher {
                        activityRepository
                            .activity
                            .receive(on: DispatchQueue.main)
                            .map { .onActivityFetched(.success($0)) }
                    }
                }

            case .onAllActivityTapped:
                return .none
            case .onActivityRowTapped:
                return .none

            case .onActivityFetched(.success(let activity)):
                guard activity.isNotEmpty else {
                    state.viewState = .empty
                    return .none
                }
                state.viewState = .data
                let maxItems = 5
                let displayableElements = Array(activity.prefix(maxItems))
                let items = displayableElements
                    .map {
                        DashboardActivityRow.State(
                            isLastRow: $0.id == displayableElements.last?.id,
                            activity: $0
                        )
                    }
                state.activityRows = IdentifiedArrayOf(uniqueElements: items)
                return .none
            }
        }
        .forEach(\.activityRows, action: /Action.onActivityRowTapped) {
            DashboardActivityRow(app: app)
        }
    }
}

func providePlaceholderItems() -> IdentifiedArrayOf<DashboardActivityRow.State> {
    let value = ["a", "b", "c", "d"].map { id in
        DashboardActivityRow.State(
            isLastRow: id == "d",
            activity: .init(
                id: "a",
                type: .buy,
                network: "bitcoin-\(id)",
                pubKey: id,
                externalUrl: "",
                item: .init(leading: [
                    .text(.init(value: "\(id) this is a title", style: .init(typography: .paragraph2, color: .title))),
                    .text(.init(value: "subtitle", style: .init(typography: .caption1, color: .title)))
                ], trailing: [
                    .text(.init(value: "\(id) another title", style: .init(typography: .paragraph2, color: .title))),
                    .text(.init(value: "and subtitle", style: .init(typography: .caption1, color: .title)))
                ]),
                state: .unknown,
                timestamp: .month,
                transactionType: nil
            )
        )
    }
    return IdentifiedArrayOf<DashboardActivityRow.State>(uniqueElements: value)
}
