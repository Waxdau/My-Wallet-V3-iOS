import BlockchainComponentLibrary
import BlockchainUI
import ComposableArchitecture
import FeatureDashboardDomain
import FeatureTransactionUI
import Localization
import SwiftUI

public struct AllAssetsSceneView: View {

    private typealias L10n = LocalizationConstants.SuperApp.AllAssets

    @BlockchainApp var app
    @Environment(\.context) var context
    @ObservedObject var viewStore: ViewStoreOf<AllAssetsScene>
    let store: StoreOf<AllAssetsScene>

    public init(store: StoreOf<AllAssetsScene>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    @ViewBuilder
    public var body: some View {
        VStack {
            searchBarSection
            allAssetsSection
        }
        .background(Color.semantic.light.ignoresSafeArea())
        .navigationBarHidden(true)
        .superAppNavigationBar(
            leading: {
                Button {
                    viewStore.send(.onFilterTapped)
                } label: {
                    Icon
                        .filterv2
                        .color(.semantic.text)
                        .small()
                }
                .if(viewStore.showSmallBalances) { $0.highlighted() }
            },
            title: {
                Text(L10n.title)
                    .typography(.body2)
                    .foregroundColor(.semantic.title)
            },
            trailing: {
                IconButton(icon: .navigationCloseButton()) {
                    $app.post(event: blockchain.ux.user.assets.all.article.plain.navigation.bar.button.close.tap)
                }
                .frame(width: 24.pt, height: 24.pt)
            },
            scrollOffset: nil
        )
        .bottomSheet(
            isPresented: viewStore.$filterPresented.animation(.spring()),
            content: {
                filterSheet
            }
        )
        .batch {
            set(blockchain.ux.user.assets.all.article.plain.navigation.bar.button.close.tap.then.close, to: true)
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
    }

    @ViewBuilder
    private var searchBarSection: some View {
        SearchBar(
            text: viewStore.$searchText,
            isFirstResponder: viewStore.$isSearching,
            cancelButtonText: L10n.cancelButton,
            placeholder: L10n.searchPlaceholder
        )
        .frame(height: 48)
        .padding(.horizontal, Spacing.padding2)
        .padding(.vertical, Spacing.padding3)
    }

    @ViewBuilder
    private var allAssetsSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch viewStore.searchResults {
                case .some(let value) where value.isNotEmpty:
                    let lastId = value.last?.id
                    let isCustodial = viewStore.presentedAssetType.isCustodial
                    ForEach(value) { item in
                        rowView(item, isLast: item.id == lastId, isCustodial: isCustodial)
                    }
                case .some:
                    noResultsView
                case nil:
                    loadingSection
                }
            }
            .cornerRadius(16, corners: .allCorners)
            .padding(.horizontal, Spacing.padding2)
        }
    }

    @ViewBuilder
    private func rowView(
        _ value: AssetBalanceInfo,
        isLast: Bool,
        isCustodial: Bool
    ) -> some View {
        if let balance = value.balance {
            balance.rowView(
                isCustodial ? .delta : .quote,
                byline: { if isCustodial.isNo { MoneyValueCodeNetworkView(balance.currencyType) } }
            )
            .onTapGesture {
                viewStore.send(.set(\.$isSearching, false))
                viewStore.send(.onAssetTapped(value))
            }
            if isLast.isNo {
                PrimaryDivider()
            }
        }
    }

    @ViewBuilder
    private var filterSheet: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    Spacer()
                    Text(L10n.Filter.title)
                        .typography(.body2)
                        .foregroundColor(.semantic.title)
                    Spacer()
                }
                Button(
                    action: { viewStore.send(.onResetTapped) },
                    label: {
                        Text(L10n.Filter.resetButton)
                            .typography(.paragraph2)
                            .foregroundColor(.semantic.primaryMuted)
                    }
                )
                .frame(minHeight: Spacing.padding3)
                .padding(.trailing, Spacing.padding2)
            }
            .padding(.top, Spacing.padding1)
            .padding(.bottom, Spacing.padding3)

            HStack(spacing: 0) {
                Text(L10n.Filter.showSmallBalancesLabel)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
                    .padding(.leading, Spacing.padding2)
                Spacer()
                PrimarySwitch(
                    accessibilityLabel: "",
                    isOn: viewStore.$showSmallBalances
                )
                .frame(height: 32.pt)
                .padding(.trailing, Spacing.padding2)
                .padding(.vertical, 12)
            }
            .background(Color.semantic.light)
            .cornerRadius(16, corners: .allCorners)
            .padding(.horizontal, Spacing.padding2)

            PrimaryButton(title: L10n.Filter.showButton) {
                viewStore.send(.onConfirmFilterTapped)
            }
            .frame(height: 56.pt)
            .padding(.horizontal, Spacing.padding2)
            .padding(.vertical, Spacing.padding3)
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        Group {
            SimpleBalanceRow(leadingTitle: "", trailingDescription: nil, leading: {})
            PrimaryDivider()
            SimpleBalanceRow(leadingTitle: "", trailingDescription: nil, leading: {})
            PrimaryDivider()
            SimpleBalanceRow(leadingTitle: "", trailingDescription: nil, leading: {})
        }
    }

    @ViewBuilder
    private var noResultsView: some View {
        HStack(alignment: .center) {
            Text(L10n.noResults)
                .padding(.vertical, Spacing.padding2)
        }
        .frame(maxWidth: .infinity)
        .background(Color.semantic.background)
    }
}
