// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ComposableArchitecture
import ComposableNavigation
import FeatureCryptoDomainDomain
import SwiftUI
import ToolKit

// MARK: - Type

enum SearchCryptoDomainRoute: NavigationRoute {

    case checkout

    @ViewBuilder
    func destination(in store: Store<SearchCryptoDomainState, SearchCryptoDomainAction>) -> some View {
        switch self {
        case .checkout:
            IfLetStore(
                store.scope(
                    state: \.checkoutState,
                    action: SearchCryptoDomainAction.checkoutAction
                ),
                then: DomainCheckoutView.init(store:)
            )
        }
    }
}

enum SearchCryptoDomainAction: Equatable, NavigationAction, BindableAction {
    case route(RouteIntent<SearchCryptoDomainRoute>?)
    case binding(BindingAction<SearchCryptoDomainState>)
    case checkoutAction(DomainCheckoutAction)
}

// MARK: - Properties

struct SearchCryptoDomainState: Equatable, NavigationState {

    @BindableState var searchText: String
    @BindableState var isSearchFieldSelected: Bool
    @BindableState var isAlertCardShown: Bool
    var searchResults: [SearchDomainResult]
    var filteredSearchResults: [SearchDomainResult]
    var route: RouteIntent<SearchCryptoDomainRoute>?
    var checkoutState: DomainCheckoutState?

    init(
        searchText: String = "",
        isSearchFieldSelected: Bool = false,
        isAlertCardShown: Bool = true,
        searchResults: [SearchDomainResult] = [],
        route: RouteIntent<SearchCryptoDomainRoute>? = nil,
        checkoutState: DomainCheckoutState? = nil
    ) {
        self.searchText = searchText
        self.isSearchFieldSelected = isSearchFieldSelected
        self.isAlertCardShown = isAlertCardShown
        self.searchResults = searchResults
        filteredSearchResults = searchResults
        self.route = route
        self.checkoutState = checkoutState
    }
}

struct SearchCryptoDomainEnvironment {

    let mainQueue: AnySchedulerOf<DispatchQueue>
    let fuzzyAlgorithm = FuzzyAlgorithm(caseInsensitive: true)
    let fuzzyTolerance = 0.3

    init(mainQueue: AnySchedulerOf<DispatchQueue>) {
        self.mainQueue = mainQueue
    }
}

let searchCryptoDomainReducer = Reducer.combine(
    domainCheckoutReducer
        .optional()
        .pullback(
            state: \.checkoutState,
            action: /SearchCryptoDomainAction.checkoutAction,
            environment: { _ in () }
        ),
    Reducer<
        SearchCryptoDomainState,
        SearchCryptoDomainAction,
        SearchCryptoDomainEnvironment
    > { state, action, environment in
        switch action {
        case .binding(\.$searchText):
            if state.searchText.isEmpty {
                state.filteredSearchResults = state.searchResults
            } else {
                state.filteredSearchResults = state.searchResults.filter {
                    let fuzzy = environment.fuzzyAlgorithm
                    let tolerance = environment.fuzzyTolerance
                    return fuzzy.distance(
                        between: $0.domainName,
                        and: state.searchText
                    ) < tolerance || fuzzy.distance(
                        between: $0.domainName,
                        and: state.searchText
                    ) < tolerance
                }
            }
            return .none
        case .binding:
            return .none
        case .route(let route):
            if let routeValue = route?.route {
                switch routeValue {
                case .checkout:
                    state.checkoutState = .init()
                }
            }
            return .none
        case .checkoutAction:
            return .none
        }
    }
    .routing()
    .binding()
)
