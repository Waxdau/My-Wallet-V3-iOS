// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import Coincore
import Combine
import ComposableArchitecture
import ComposableArchitectureExtensions
import Localization
import SwiftUI
import UIComponentsKit

public struct AccountPickerView<
    BadgeView: View,
    DescriptionView: View,
    IconView: View,
    MultiBadgeView: View,
    WithdrawalLocksView: View
>: View {

    // MARK: - Internal properties

    let store: StoreOf<AccountPicker>
    @ViewBuilder let badgeView: (AnyHashable) -> BadgeView
    @ViewBuilder let descriptionView: (AnyHashable) -> DescriptionView
    @ViewBuilder let iconView: (AnyHashable) -> IconView
    @ViewBuilder let multiBadgeView: (AnyHashable) -> MultiBadgeView
    @ViewBuilder let withdrawalLocksView: () -> WithdrawalLocksView

    // MARK: - Private properties

    @State private var isSearching: Bool = false
    @State private var controlSelection: Tag = blockchain.ux.asset.account.swap.segment.filter.defi[]
    @State var transactionFlowAction: AssetAction?
    @State var popularAssets: [String] = []

    // MARK: - Init

    init(
        store: StoreOf<AccountPicker>,
        @ViewBuilder badgeView: @escaping (AnyHashable) -> BadgeView,
        @ViewBuilder descriptionView: @escaping (AnyHashable) -> DescriptionView,
        @ViewBuilder iconView: @escaping (AnyHashable) -> IconView,
        @ViewBuilder multiBadgeView: @escaping (AnyHashable) -> MultiBadgeView,
        @ViewBuilder withdrawalLocksView: @escaping () -> WithdrawalLocksView
    ) {
        self.store = store
        self.badgeView = badgeView
        self.descriptionView = descriptionView
        self.iconView = iconView
        self.multiBadgeView = multiBadgeView
        self.withdrawalLocksView = withdrawalLocksView
    }

    public init(
        accountPicker: AccountPicker,
        @ViewBuilder badgeView: @escaping (AnyHashable) -> BadgeView,
        @ViewBuilder descriptionView: @escaping (AnyHashable) -> DescriptionView,
        @ViewBuilder iconView: @escaping (AnyHashable) -> IconView,
        @ViewBuilder multiBadgeView: @escaping (AnyHashable) -> MultiBadgeView,
        @ViewBuilder withdrawalLocksView: @escaping () -> WithdrawalLocksView
    ) {
        self.init(
            store: Store(
                initialState: AccountPickerState(
                    sections: .loading,
                    header: .init(headerStyle: .none, searchText: ""),
                    fiatBalances: [:],
                    cryptoBalances: [:],
                    currencyCodes: [:]
                ),
                reducer: { accountPicker }
            ),
            badgeView: badgeView,
            descriptionView: descriptionView,
            iconView: iconView,
            multiBadgeView: multiBadgeView,
            withdrawalLocksView: withdrawalLocksView
        )
    }

    // MARK: - Body

    public var body: some View {
        StatefulView(
            store: store.scope(state: \.sections, action: { $0 }),
            loadedAction: AccountPickerAction.rowsLoaded,
            loadingAction: AccountPickerAction.rowsLoading,
            successAction: LoadedRowsAction.success,
            failureAction: LoadedRowsAction.failure,
            loading: { _ in
                LoadingStateView(title: "")
            },
            success: { successStore in
                WithViewStore(successStore, observe: \.content.isEmpty) { viewStore in
                    if viewStore.state {
                        emptyState
                    } else {
                        contentView(successStore: successStore)
                    }
                }
            },
            failure: { _ in
                errorStateView
            }
        )
        .onAppear {
            ViewStore(store, observe: { $0 }).send(.subscribeToUpdates)
        }
    }

    @ViewBuilder
    private var errorStateView: some View {
        VStack(spacing: Spacing.padding2) {
            Text(LocalizationConstants.Errors.genericError)
                .typography(.title3)
                .foregroundColor(.semantic.title)
        }
        .padding([.leading, .trailing], 24)
    }

    struct HeaderScope: Equatable {
        var header: AccountPickerState.HeaderState
        var selected: AnyHashable?
        var toggled: AnyHashable?
    }

    @ViewBuilder func contentView(
        successStore: Store<Sections, SuccessRowsAction>
    ) -> some View {
        VStack(spacing: .zero) {
            WithViewStore(store, observe: { HeaderScope(header: $0.header, selected: $0.selected) }) { viewStore in
                HeaderView(
                    viewModel: viewStore.header.headerStyle,
                    searchText: Binding<String>(
                        get: { viewStore.header.searchText },
                        set: { viewStore.send(.search($0)) }
                    ),
                    isSearching: $isSearching,
                    segmentedControlSelection: $controlSelection
                )
                .onChange(of: viewStore.selected) { _ in
                    isSearching = false
                    viewStore.send(.deselect)
                }
            }

            List {
                WithViewStore(
                    successStore,
                    observe: { $0 },
                    removeDuplicates: { $0.identifier == $1.identifier },
                    content: { viewStore in
                        ForEach(viewStore.content) { section in

                            if case .warning(let dialogs) = section {
                                Section {
                                    WarningView(dialogs)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }

                            if case .accounts(let rows) = section {
                                    rowSection(
                                        rows: rows,
                                        viewStore: viewStore
                                    )
                            }
                        }
                    }
                )
            }
            .hideScrollContentBackground()
            .background(Color.semantic.light.ignoresSafeArea())
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 1)
            .animation(.easeInOut, value: isSearching)
            .bindings {
                subscribe($transactionFlowAction, to: blockchain.ux.transaction.id)
                subscribe($popularAssets, to: blockchain.app.configuration.buy.most.popular.assets)
            }
        }
    }

    @ViewBuilder
    func rowSection(
        title: String? = nil,
        rows: [AccountPickerRow],
        viewStore: ViewStore<Sections, SuccessRowsAction>
    ) -> some View {
        Section {
            ForEach(rows.indexed(), id: \.element.id) { index, row in
                WithViewStore(store, observe: { $0.balances(for: row.id) }) { balancesStore in
                    AccountPickerRowView(
                        model: row,
                        send: { action in
                            viewStore.send(action)
                        },
                        badgeView: badgeView,
                        descriptionView: descriptionView,
                        iconView: iconView,
                        multiBadgeView: multiBadgeView,
                        withdrawalLocksView: withdrawalLocksView,
                        fiatBalance: balancesStore.fiat,
                        cryptoBalance: balancesStore.crypto,
                        currencyCode: balancesStore.currencyCode,
                        lastItem: rows.last?.id == row.id
                    )
                    .listRowSeparatorTint(Color.semantic.light)
                    .background(Color.semantic.background)
                    .id(row.id)
                    .onAppear {
                        ViewStore(store, observe: { $0 })
                            .send(.prefetching(.onAppear(index: index)))
                    }
                    .onChange(of: controlSelection, perform: { newValue in
                        ViewStore(store, observe: { $0 })
                            .send(.onSegmentSelectionChanged(newValue))

                        let indices = Set(viewStore.content.accountRows.indices)

                        ViewStore(store, observe: { $0 })
                            .send(.prefetching(.requeue(indices: indices)))
                    })
                }
            }
        } header: {
            Text(title ?? "")
                .typography(.body2)
                .textCase(nil)
                .foregroundColor(.semantic.body)
                .padding(.bottom, Spacing.padding1)
        }
        .listRowInsets(EdgeInsets(top: Spacing.padding1, leading: 0, bottom: 0, trailing: 0))
    }

    func topRows(from rows: [AccountPickerRow]) -> [AccountPickerRow] {
        rows.filter {
            guard let currency = $0.currency else {
                return false
            }
            return popularAssets.contains(currency)
        }
    }

    func otherRows(from rows: [AccountPickerRow]) -> [AccountPickerRow] {
        rows.filter {
            guard let currency = $0.currency else {
                return false
            }
            return popularAssets.contains(currency) == false
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack {
            Text(LocalizationConstants.AccountPicker.noWallets)
                .textStyle(.title)
                .foregroundColor(.semantic.title)

            Spacer()
                .frame(height: 8)

            Text("")
                .textStyle(.subheading)
                .foregroundColor(.semantic.text)

            Spacer()
                .frame(height: 24)

            ImageAsset.emptyActivity.imageResource.image
        }
    }
}

struct AccountPickerView_Previews: PreviewProvider {
    static let allIdentifier = UUID()
    static let btcWalletIdentifier = UUID()
    static let btcTradingWalletIdentifier = UUID()
    static let ethWalletIdentifier = UUID()
    static let bchWalletIdentifier = UUID()
    static let bchTradingWalletIdentifier = UUID()

    static let fiatBalances: [AnyHashable: String] = [
        allIdentifier: "$2,302.39",
        btcWalletIdentifier: "$2,302.39",
        btcTradingWalletIdentifier: "$10,093.13",
        ethWalletIdentifier: "$807.21",
        bchWalletIdentifier: "$807.21",
        bchTradingWalletIdentifier: "$40.30"
    ]

    static let currencyCodes: [AnyHashable: String] = [
        allIdentifier: "USD"
    ]

    static let cryptoBalances: [AnyHashable: String] = [
        btcWalletIdentifier: "0.21204887 BTC",
        btcTradingWalletIdentifier: "1.38294910 BTC",
        ethWalletIdentifier: "0.17039384 ETH",
        bchWalletIdentifier: "0.00388845 BCH",
        bchTradingWalletIdentifier: "0.00004829 BCH"
    ]

    static let accountPickerSections: [AccountPickerSection] = [
        .accounts([
            .accountGroup(
                AccountPickerRow.AccountGroup(
                    id: allIdentifier,
                    title: "All Wallets",
                    description: "Total Balance"
                )
            ),
            .button(
                AccountPickerRow.Button(
                    id: UUID(),
                    text: "See Balance"
                )
            ),
            .singleAccount(
                AccountPickerRow.SingleAccount(
                    id: btcWalletIdentifier,
                    currency: "BTC",
                    title: "BTC Wallet",
                    description: "Bitcoin"
                )
            ),
            .singleAccount(
                AccountPickerRow.SingleAccount(
                    id: btcTradingWalletIdentifier,
                    currency: "BTC",
                    title: "BTC Trading Wallet",
                    description: "Bitcoin"
                )
            ),
            .singleAccount(
                AccountPickerRow.SingleAccount(
                    id: ethWalletIdentifier,
                    currency: "BTC",
                    title: "ETH Wallet",
                    description: "Ethereum"
                )
            ),
            .singleAccount(
                AccountPickerRow.SingleAccount(
                    id: bchWalletIdentifier,
                    currency: "BTC",
                    title: "BCH Wallet",
                    description: "Bitcoin Cash"
                )
            ),
            .singleAccount(
                AccountPickerRow.SingleAccount(
                    id: bchTradingWalletIdentifier,
                    currency: "BTC",
                    title: "BCH Trading Wallet",
                    description: "Bitcoin Cash"
                )
        ),
            .button(
            AccountPickerRow.Button(
                id: UUID(),
                text: "See Balance"
            )
        ),
            .singleAccount(
            AccountPickerRow.SingleAccount(
                id: btcWalletIdentifier,
                currency: "BTC",
                title: "BTC Wallet",
                description: "Bitcoin"
            )
        ),
            .singleAccount(
            AccountPickerRow.SingleAccount(
                id: btcTradingWalletIdentifier,
                currency: "BTC",
                title: "BTC Trading Wallet",
                description: "Bitcoin"
            )
        ),
            .singleAccount(
            AccountPickerRow.SingleAccount(
                id: ethWalletIdentifier,
                currency: "ETH",
                title: "ETH Wallet",
                description: "Ethereum"
            )
        ),
            .singleAccount(
            AccountPickerRow.SingleAccount(
                id: bchWalletIdentifier,
                currency: "BTC",
                title: "BCH Wallet",
                description: "Bitcoin Cash"
            )
        ),
            .singleAccount(
            AccountPickerRow.SingleAccount(
                id: bchTradingWalletIdentifier,
                currency: "BCH",
                title: "BCH Trading Wallet",
                description: "Bitcoin Cash"
            ))
        ]
       )
    ]

    static let header = AccountPickerState.HeaderState(
        headerStyle: .normal(
            title: "Send Crypto Now",
            subtitle: "Choose a Wallet to send cypto from.",
            image: ImageAsset.iconSend.imageResource,
            tableTitle: "Select a Wallet",
            searchable: true
        ),
        searchText: ""
    )

    @ViewBuilder static func view(
        sections: LoadingState<Result<Sections, AccountPickerError>>
    ) -> some View {
        AccountPickerView(
            store: Store(
                initialState: AccountPickerState(
                    sections: sections,
                    header: header,
                    fiatBalances: fiatBalances,
                    cryptoBalances: cryptoBalances,
                    currencyCodes: currencyCodes
                ),
                reducer: {
                    AccountPicker(
                        app: App.preview,
                        rowSelected: { _ in },
                        uxSelected: { _ in },
                        backButtonTapped: {},
                        closeButtonTapped: {},
                        search: { _ in },
                        sections: { Just(Array(accountPickerSections)).eraseToAnyPublisher() },
                        updateSingleAccounts: { _ in .just([:]) },
                        updateAccountGroups: { _ in .just([:]) },
                        header: { Just(header.headerStyle).setFailureType(to: Error.self).eraseToAnyPublisher() },
                        onSegmentSelectionChanged: { _ in }
                    )
                }
            ),
            badgeView: { _ in EmptyView() },
            descriptionView: { _ in EmptyView() },
            iconView: { _ in EmptyView() },
            multiBadgeView: { _ in EmptyView() },
            withdrawalLocksView: { EmptyView() }
        )
    }

    static var previews: some View {
        view(sections: .loaded(next: .success(Sections(content: accountPickerSections))))
            .previewDisplayName("Success")

        view(sections: .loaded(next: .success(Sections(content: []))))
            .previewDisplayName("Empty")

        view(sections: .loaded(next: .failure(.testError)))
            .previewDisplayName("Error")

        view(sections: .loading)
            .previewDisplayName("Loading")
    }
}

extension [AccountPickerSection] {
    fileprivate var accountRows: [AccountPickerRow] {
        var allRows: [AccountPickerRow] = []
        for section in self {
            switch section {
            case .accounts(let rows):
                allRows.append(contentsOf: rows)
            default:
                break
            }
        }
        return allRows
    }
}
