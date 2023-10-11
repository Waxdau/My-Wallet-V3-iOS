// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import ComposableArchitecture
import ComposableNavigation
import Errors
import FeatureAddressSearchDomain
import Localization
import MoneyKit
import SwiftUI
import ToolKit

enum AddressSearchAction: Equatable, BindableAction, NavigationAction {

    case onAppear
    case route(RouteIntent<AddressSearchRoute>?)
    case searchAddresses(searchText: String?, country: String?)
    case didReceiveAddressesResult(Result<[AddressSearchResult], AddressSearchServiceError>)
    case selectAddress(AddressSearchResult)
    case modifySelectedAddress(addressId: String?)
    case modifyAddress
    case updateSelectedAddress(Address)
    case addressModificationAction(AddressModificationAction)
    case closeError
    case cancelSearch
    case complete(AddressResult)
    case binding(BindingAction<AddressSearchState>)
}

struct AddressSearchIdentifier: Hashable {}
let AddressSearchDebounceInMilliseconds: Int = 500

struct AddressSearchState: Equatable, NavigationState {

    struct ContainerSearch: Equatable {
        let containerId: String?
        let searchText: String?
    }

    @BindingState var searchText: String = ""
    @BindingState var isSearchFieldSelected: Bool = false
    var isSearchResultsLoading: Bool = false
    var searchResults: [AddressSearchResult] = []
    var isAddressSearchResultsNotFoundVisible: Bool {
        searchText.isNotEmpty && searchResults.isEmpty && !isSearchResultsLoading
    }

    var address: Address?
    var route: RouteIntent<AddressSearchRoute>?
    var addressModificationState: AddressModificationState?
    var loading = false
    var screenTitle: String = ""
    var screenSubtitle: String = ""
    var containerSearch: ContainerSearch?
    var error: Nabu.Error?

    init(
        address: Address? = nil,
        error: Nabu.Error? = nil,
        searchResults: [AddressSearchResult] = []
    ) {
        self.address = address
        self.searchResults = searchResults
        self.error = error
        self.route = nil
        self.searchText = address?.searchText ?? ""
    }
}

struct AddressSearchEnvironment {}

struct AddressSearchReducer: Reducer {

    let mainQueue: AnySchedulerOf<DispatchQueue>
    let config: AddressSearchFeatureConfig
    let addressService: AddressServiceAPI
    let addressSearchService: AddressSearchServiceAPI
    let onComplete: (AddressResult) -> Void

    init(
        mainQueue: AnySchedulerOf<DispatchQueue>,
        config: AddressSearchFeatureConfig,
        addressService: AddressServiceAPI,
        addressSearchService: AddressSearchServiceAPI,
        onComplete: @escaping (AddressResult) -> Void
    ) {
        self.mainQueue = mainQueue
        self.config = config
        self.addressService = addressService
        self.addressSearchService = addressSearchService
        self.onComplete = onComplete
    }

    typealias State = AddressSearchState
    typealias Action = AddressSearchAction

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.$searchText):
                return Effect.send(
                    .searchAddresses(
                        searchText: state.searchText,
                        country: state.address?.country
                    )
                )

            case .selectAddress(let searchAddressResult):
                if searchAddressResult.isAddressType {
                    return Effect.send(.modifySelectedAddress(addressId: searchAddressResult.addressId))
                } else {
                    let searchText = (searchAddressResult.text ?? "") + " "
                    state.searchText = searchText
                    state.containerSearch = .init(
                        containerId: searchAddressResult.addressId,
                        searchText: searchText
                    )
                    return Effect.send(
                        .searchAddresses(
                            searchText: state.searchText,
                            country: state.address?.country
                        )
                    )
                }

            case .modifySelectedAddress(let addressId):
                return Effect.send(
                    .navigate(to: .modifyAddress(
                        selectedAddressId: addressId,
                        address: state.address
                    ))
                )

            case .modifyAddress:
                return Effect.send(
                    .navigate(to: .modifyAddress(
                        selectedAddressId: nil,
                        address: state.address
                    ))
                )

            case .onAppear:
                state.screenTitle = config.addressSearchScreen.title
                state.screenSubtitle = config.addressSearchScreen.subtitle
                guard state.address == .none else {
                    if state.searchResults.isEmpty {
                        state.containerSearch = nil
                        return Effect.send(
                            .searchAddresses(
                                searchText: state.address?.searchText,
                                country: state.address?.country
                            )
                        )
                    } else {
                        return .none
                    }
                }
                return .none

            case .route(let route):
                if let routeValue = route?.route {
                    switch routeValue {
                    case .modifyAddress(let selectedAddressId, let address):
                        state.addressModificationState = .init(
                            addressDetailsId: selectedAddressId,
                            country: address?.country,
                            state: address?.state,
                            isPresentedFromSearchView: true
                        )
                        state.route = route
                    }
                } else {
                    state.addressModificationState = nil
                    state.route = route
                }
                return .none

            case .closeError:
                state.error = nil
                return .none

            case .binding:
                return .none

            case .updateSelectedAddress(let address):
                state.address = address
                return Effect.send(.complete(.saved(address)))

            case .cancelSearch:
                return Effect.send(.complete(.abandoned))

            case .complete(let addressResult):
                onComplete(addressResult)
                return .none

            case .searchAddresses(let searchText, let country):
                guard let searchText, searchText.isNotEmpty,
                      let country, country.isNotEmpty
                else {
                    state.searchResults = []
                    state.isSearchResultsLoading = false
                    state.containerSearch = nil
                    return .cancel(id: AddressSearchIdentifier())
                }
                if let containerSearchText = state.containerSearch?.searchText {
                    if !searchText.hasPrefix(containerSearchText) {
                        state.containerSearch = nil
                    }
                }
                state.isSearchResultsLoading = true
                return .run { [state] send in
                    do {
                        let addresses = try await addressSearchService
                            .fetchAddresses(
                                searchText: searchText,
                                containerId: state.containerSearch?.containerId,
                                countryCode: country,
                                sateCode: state.address?.state
                            )
                            .await()
                        await send(.didReceiveAddressesResult(.success(addresses)))
                    } catch let error as AddressSearchServiceError {
                        await send(.didReceiveAddressesResult(.failure(error)))
                    }
                    catch {
                        print("\(error.localizedDescription)")
                    }
                }
                .debounce(
                    id: AddressSearchIdentifier(),
                    for: .milliseconds(AddressSearchDebounceInMilliseconds),
                    scheduler: mainQueue
                )

            case .didReceiveAddressesResult(let result):
                state.isSearchResultsLoading = false
                switch result {
                case .success(let searchedAddresses):
                    state.searchResults = searchedAddresses
                case .failure(let error):
                    state.error = error.nabuError
                }
                return .none

            case .addressModificationAction(let modificationAction):
                switch modificationAction {
                case .updateAddressResponse(.success(let address)):
                    state.address = address
                    return .merge(
                        Effect.send(.dismiss()),
                        Effect.send(.updateSelectedAddress(address))
                    )
                case .cancelEdit:
                    return .none
                case .alert(.presented(.stateDoesNotMatch)):
                    state.route = nil
                    return .none
                default:
                    return .none
                }
            }
        }
        .ifLet(\.addressModificationState, action: /Action.addressModificationAction) {
            AddressModificationReducer(
                mainQueue: mainQueue,
                config: config.addressEditScreen,
                addressService: addressService,
                addressSearchService: addressSearchService
            )
        }
    }
}

extension Address {
    var searchText: String {
        [
            postCode,
            line1,
            city
        ]
            .compactMap { $0 }
            .filter(\.isNotEmpty)
            .joined(separator: " ")
    }
}

extension AddressSearchServiceError {
    var nabuError: Nabu.Error {
        switch self {
        case .network(let error):
            return error
        }
    }
}

#if DEBUG

struct MockServices: AddressSearchServiceAPI {

    static let addressId = "GB|RM|B|27354762"

    static let address = Address(
        line1: "614 Lorimer Street",
        line2: nil,
        city: "",
        postCode: "11111",
        state: "CA",
        country: "US"
    )

    func fetchAddresses(
        searchText: String,
        containerId: String?,
        countryCode: String,
        sateCode: String?
    ) -> AnyPublisher<[AddressSearchResult], AddressSearchServiceError> {
        .just([])
    }

    func fetchAddress(addressId: String) -> AnyPublisher<AddressDetailsSearchResult, AddressSearchServiceError> {
        .just(
            .init(
                addressId: "GB|TS|A|2966",
                line1: "32 Evergreen Boulevard",
                street: "Evergreen Boulevard",
                buildingNumber: "32",
                city: "Gotham City",
                postCode: "89109-1234",
                state: "AZ",
                country: "US",
                label: "32 Evergreen Boulevard \nGOTHAM CITY\n89109-1234\nUNITED STATES"
            )
        )
    }
}

extension MockServices: AddressServiceAPI {
    func fetchAddress() -> AnyPublisher<Address?, AddressServiceError> {
        .just(Self.address)
    }

    func save(address: Address) -> AnyPublisher<Address, AddressServiceError> {
        .just(Self.address)
    }
}
#endif
