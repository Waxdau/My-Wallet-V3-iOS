// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import FeatureOpenBankingDomain
import SwiftUI
import UIComponentsKit

// swiftlint:disable:next type_name
typealias BlockchainComponentLibrarySecondaryButton = BlockchainComponentLibrary.SecondaryButton

public struct InstitutionListState: Equatable, NavigationState {

    public var route: RouteIntent<InstitutionListRoute>?

    var result: Result<OpenBanking.BankAccount, OpenBanking.Error>?
    var selection: BankState?
}

public enum InstitutionListAction: Hashable, NavigationAction, FailureAction {

    case route(RouteIntent<InstitutionListRoute>?)
    case failure(OpenBanking.Error)

    case fetch
    case fetched(OpenBanking.BankAccount)
    case select(OpenBanking.BankAccount, OpenBanking.Institution)
    case showTransferDetails

    case bank(BankAction)

    case dismiss
}

public enum InstitutionListRoute: CaseIterable, NavigationRoute {

    case bank

    @ViewBuilder
    public func destination(in store: Store<InstitutionListState, InstitutionListAction>) -> some View {
        switch self {
        case .bank:
            IfLetStore(
                store.scope(state: \.selection, action: InstitutionListAction.bank),
                then: BankView.init(store:)
            )
        }
    }
}

public struct InstitutionListReducer: Reducer {

    public typealias State = InstitutionListState
    public typealias Action = InstitutionListAction

    let environment: OpenBankingEnvironment

    public init(environment: OpenBankingEnvironment) {
        self.environment = environment
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .route(let route):
                state.route = route
                return .none
            case .fetch:
                return .publisher {
                    environment.openBanking
                        .createBankAccount()
                        .receive(on: environment.scheduler)
                        .map(InstitutionListAction.fetched)
                        .catch(InstitutionListAction.failure)
                }
            case .fetched(let account):
                state.result = .success(account)
                return .none
            case .showTransferDetails:
                environment.showTransferDetails()
                return .none
            case .select(let account, let institution):
                state.selection = .init(
                    data: .init(
                        account: account,
                        action: .link(institution: institution)
                    )
                )
                return .merge(
                    .navigate(to: .bank),
                    .run { _ in
                        environment.analytics.record(
                            event: .linkBankSelected(institution: institution.name, account: account)
                        )
                    }
                )
            case .bank(.cancel):
                state.route = nil
                state.result = nil
                return Effect.send(.fetch)
            case .bank:
                return .none
            case .dismiss:
                environment.dismiss()
                return .none
            case .failure(let error):
                state.result = .failure(error)
                return .none
            }
        }
        .ifLet(\.selection, action: /Action.bank) {
            BankReducer(environment: environment)
        }
    }
}

public struct InstitutionList: View {

    @BlockchainApp var app

    private let store: Store<InstitutionListState, InstitutionListAction>

    @State private var loading: CGFloat = 44
    @State private var padding: CGFloat = 40

    public init(store: Store<InstitutionListState, InstitutionListAction>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store.scope(state: \.result, action: { $0 }), observe: { $0 }) { viewStore in
            ZStack {
                switch viewStore.state {
                case .success(let account) where account.attributes.institutions != nil:
                    SearchableList(
                        account.attributes.institutions.or(default: []),
                        placeholder: Localization.InstitutionList.search,
                        content: { bank in
                            Item(bank) {
                                viewStore.send(.select(account, bank))
                            }
                        },
                        empty: {
                            NoSearchResults
                        }
                    ).background(Color.semantic.background)
                case .failure(let error):
                    InfoView(
                        .init(
                            media: .bankIcon,
                            overlay: .init(media: .error),
                            title: Localization.Error.title,
                            subtitle: "\(error.description)"
                        )
                    )
                default:
                    ProgressView(value: 0.25)
                        .frame(width: 12.vmin, alignment: .center)
                        .aspectRatio(1, contentMode: .fit)
                        .progressViewStyle(.indeterminate)
                        .onAppear { viewStore.send(.fetch) }
                }
            }
            .navigationRoute(in: store)
            .navigationTitle(Localization.InstitutionList.title)
            .whiteNavigationBarStyle()
            .trailingNavigationButton(.close) {
                viewStore.send(.dismiss)
            }
        }
    }

    @ViewBuilder var NoSearchResults: some View {
        WithViewStore(store, observe: { $0 }) { view in
            Spacer()
            Text(Localization.InstitutionList.Error.couldNotFindBank)
                .typography(.paragraph1)
                .foregroundColor(.semantic.text)
                .frame(alignment: .center)
                .multilineTextAlignment(.center)
                .padding([.leading, .trailing], 12.5.vmin)
            Spacer()
            BlockchainComponentLibrarySecondaryButton(title: Localization.InstitutionList.Error.showTransferDetails) {
                view.send(.showTransferDetails)
            }
            .padding(10.5.vmin)
        }
    }
}

extension InstitutionList {

    public struct Item: View, Identifiable {

        let institution: OpenBanking.Institution
        let action: () -> Void

        public var id: Identity<OpenBanking.Institution> { institution.id }

        private var title: String { institution.fullName }
        private var image: URL? {
            institution.media.first(where: { $0.type == .icon })?.source
                ?? institution.media.first?.source
        }

        init(_ institution: OpenBanking.Institution, action: @escaping () -> Void) {
            self.institution = institution
            self.action = action
        }

        public var body: some View {
            PrimaryRow(
                title: title,
                leading: {
                    Group {
                        if let image {
                            ImageResourceView(
                                url: image,
                                placeholder: { Color.semantic.background }
                            )
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        } else {
                            Color.viewPrimaryBackground
                        }
                    }
                    .frame(width: 12.vw, height: 12.vw, alignment: .center)
                },
                action: action
            )
            .frame(height: 9.5.vh)
            .background(Color.semantic.background)
        }
    }
}

extension OpenBanking.Institution: CustomStringConvertible, Identifiable {
    public var description: String { fullName }
}

#if DEBUG
struct InstitutionList_Previews: PreviewProvider {

    static var previews: some View {
        PrimaryNavigationView {
            InstitutionList(
                store: Store(initialState: InstitutionListState()) {
                    InstitutionListReducer(
                        environment: .mock
                    )
                }
            )
        }

        InstitutionList.Item(.mock, action: {})
    }
}
#endif
