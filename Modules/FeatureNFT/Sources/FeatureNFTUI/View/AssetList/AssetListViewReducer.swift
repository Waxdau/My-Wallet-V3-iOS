import Combine
import ComposableArchitecture
import FeatureNFTDomain
import SwiftUI
import ToolKit

private enum AssetListCancellation {
    struct RequestAssetsKeyId: Hashable {}
    struct RequestPageAssetsKeyId: Hashable {}
}

public struct AssetListReducer: ReducerProtocol {

    public typealias State = AssetListViewState
    public typealias Action = AssetListViewAction

    public let mainQueue: AnySchedulerOf<DispatchQueue>
    public let assetProviderService: AssetProviderServiceAPI
    public let pasteboard: UIPasteboard

    public init(
        mainQueue: AnySchedulerOf<DispatchQueue> = .main,
        pasteboard: UIPasteboard = .general,
        assetProviderService: AssetProviderServiceAPI
    ) {
        self.mainQueue = mainQueue
        self.pasteboard = pasteboard
        self.assetProviderService = assetProviderService
    }

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return assetProviderService
                    .fetchAssetsFromEthereumAddress()
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(AssetListViewAction.fetchedAssets)
                    .cancellable(
                        id: AssetListCancellation.RequestAssetsKeyId(),
                        cancelInFlight: true
                    )
            case .fetchedAssets(let result):
                switch result {
                case .success(let value):
                    let assets: [Asset] = state.assets + value.assets
                    state.assets = assets
                    state.next = value.cursor
                case .failure(let error):
                    state.error = error
                }
                state.isLoading = false
                state.isPaginating = false
                return .none
            case .assetTapped(let asset):
                state.assetDetailViewState = .init(asset: asset)
                return .enter(into: .details)
            case .route(let route):
                state.route = route
                return .none
            case .increaseOffset:
                guard !state.isPaginating else { return .none }
                guard state.next != nil else { return .none }
                return EffectTask(value: .fetchNextPageIfNeeded)
            case .fetchNextPageIfNeeded:
                state.isPaginating = true
                guard let cursor = state.next else {
                    impossible("Cannot page without cursor")
                }
                return assetProviderService
                    .fetchAssetsFromEthereumAddressWithCursor(cursor)
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(AssetListViewAction.fetchedAssets)
                    .cancellable(
                        id: AssetListCancellation.RequestPageAssetsKeyId(),
                        cancelInFlight: true
                    )
            case .copyEthereumAddressTapped:
                return assetProviderService
                    .address
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(AssetListViewAction.copyEthereumAddress)
            case .copyEthereumAddress(let result):
                guard let address = try? result.get() else { return .none }
                pasteboard.string = address
                return .none
            case .assetDetailsViewAction(let action):
                switch action {
                case .viewOnWebTapped:
                    return .none
                }
            }
        }
        .ifLet(\.assetDetailViewState, action: /Action.assetDetailsViewAction) {
            AssetDetailReducer()
        }
    }
}
