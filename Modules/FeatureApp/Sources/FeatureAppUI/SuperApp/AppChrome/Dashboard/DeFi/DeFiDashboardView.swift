// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import BlockchainUI
import ComposableArchitecture
import DIKit
import FeatureAnnouncementsUI
import FeatureAppDomain
import FeatureCoinUI
import FeatureDashboardUI
import FeatureProductsDomain
import FeatureQuickActions
import FeatureTopMoversCryptoUI
import FeatureWalletConnectUI
import Localization
import SwiftUI

struct DeFiDashboardView: View {
    @BlockchainApp var app

    let store: StoreOf<DeFiDashboard>

    @State var scrollOffset: CGPoint = .zero
    @State var isBlocked: Bool = false
    @State var showsWalletConnect: Bool = false
    @State var isDeFiOnly = true

    var isTradingEnabled: Bool { !isDeFiOnly }

    struct ViewState: Equatable {
        let balance: BalanceInfo?
        var isZeroBalance: Bool { balance?.balance.isZero ?? false }
        var isBalanceLoaded: Bool { balance != nil }
        init(state: DeFiDashboard.State) {
            self.balance = state.balance
        }
    }

    init(store: StoreOf<DeFiDashboard>) {
        self.store = store
    }

    var body: some View {
        WithViewStore(
            store,
            observe: ViewState.init
        ) { viewStore in
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.padding4) {

                    DashboardMainBalanceView(
                        info: .constant(viewStore.balance),
                        isPercentageHidden: viewStore.isZeroBalance
                    )
                    .padding([.top], Spacing.padding3)

                    QuickActionsView(
                        tag: blockchain.ux.user.defi.dashboard.quick.action
                    )

                    AnnouncementsView(
                        store: store.scope(
                            state: \.announcementsState,
                            action: DeFiDashboard.Action.announcementsAction
                        )
                    )

                    DashboardAnnouncementsSectionView(
                        store: store.scope(
                            state: \.announcementState,
                            action: DeFiDashboard.Action.announcementAction
                        )
                    )

                    if isBlocked {
                        blockedView
                    }

                    if viewStore.isZeroBalance {
                        DeFiDashboardToGetStartedView()
                        FinancialPromotionDisclaimerView()
                    } else {
                        DashboardAssetSectionView(
                            store: store.scope(
                                state: \.assetsState,
                                action: DeFiDashboard.Action.assetsAction
                            )
                        )
                    }

                    if showsWalletConnect {
                        DAppDashboardListView()
                    }

                    TopMoversSectionView(
                        store: store.scope(
                            state: \.topMoversState,
                            action: DeFiDashboard.Action.topMoversAction
                        )
                    )
                    .padding(.horizontal, Spacing.padding2)

                    DashboardActivitySectionView(
                        store: store.scope(
                            state: \.activityState,
                            action: DeFiDashboard.Action.activityAction
                        )
                    )

                    Group {
                        if isTradingEnabled == false {
                            NewsSectionView(api: blockchain.api.news.all)
                        }

                        DashboardHelpSectionView()
                    }
                }
                .scrollOffset($scrollOffset)
                .task {
                    await viewStore.send(.fetchBalance).finish()
                }
                .padding(.bottom, 72.pt)
                .frame(maxWidth: .infinity)
            }
            .superAppNavigationBar(
                leading: { [app] in dashboardLeadingItem(app: app) },
                title: {
                    if let balance = viewStore.balance?.balance {
                        MoneyValueView(balance)
                            .typography(.body2)
                            .foregroundColor(.semantic.title)
                    }
                },
                trailing: { [app] in dashboardTrailingItem(app: app) },
                titleShouldFollowScroll: true,
                titleExtraOffset: Spacing.padding3,
                scrollOffset: $scrollOffset.y
            )
            .background(Color.semantic.light.ignoresSafeArea(edges: .bottom))
        }
        .bindings {
            subscribe($isBlocked, to: blockchain.user.is.blocked)
            subscribe($showsWalletConnect, to: blockchain.app.configuration.wallet.connect.is.enabled)
            subscribe($isDeFiOnly, to: blockchain.app.is.DeFi.only)
        }
        .onAppear {
            $app.post(event: blockchain.ux.home.dashboard)
        }
    }

    private typealias L10n = LocalizationConstants.SuperApp.Dashboard.GetStarted.Trading
    var blockedView: some View {
        AlertCard(
            title: L10n.blockedTitle,
            message: L10n.blockedMessage,
            variant: .error,
            isBordered: true,
            footer: {
                HStack {
                    SmallSecondaryButton(
                        title: L10n.blockedContactSupport,
                        action: {
                            $app.post(event: blockchain.ux.dashboard.trading.is.blocked.contact.support.paragraph.button.primary.tap)
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
        .onAppear {
            $app.post(event: blockchain.ux.dashboard.trading.is.blocked)
        }
        .padding(.horizontal)
        .batch {
            set(blockchain.ux.dashboard.trading.is.blocked.contact.support.paragraph.button.primary.tap.then.emit, to: blockchain.ux.customer.support.show.messenger)
        }
    }
}

struct DeFiDashboardToGetStartedView: View {
    private typealias L10n = LocalizationConstants.SuperApp.Dashboard.GetStarted.Pkw
    @BlockchainApp var app
    @State var isDeFiOnly = true

    var isTradingEnabled: Bool { !isDeFiOnly }

    var body: some View {
        VStack {
            ZStack {
                Color.semantic.background
                VStack(spacing: Spacing.padding3) {
                    Image("receive_crypto_icon")
                    Text(L10n.toGetStartedTitle)
                        .typography(.title3)
                        .foregroundColor(.semantic.title)
                        .multilineTextAlignment(.center)
                    Text(isTradingEnabled ? L10n.toGetStartedSubtitle : L10n.DeFiOnly.subtitle)
                        .typography(.body1)
                        .foregroundColor(.semantic.text)
                        .multilineTextAlignment(.center)
                    PrimaryButton(
                        title: isTradingEnabled ? L10n.toGetStartedDepositCryptoButtonTitle : L10n.DeFiOnly.button,
                        action: { [app] in
                            app.post(
                                event: blockchain.ux.dashboard.empty.receive.paragraph.row.tap
                            )
                        }
                    )
                }
                .batch {
                    set(
                        blockchain.ux.dashboard.empty.receive.paragraph.row.event.select.then.enter.into,
                        to: blockchain.ux.currency.receive.select.asset
                    )
                }
                .bindings {
                    subscribe($isDeFiOnly, to: blockchain.app.is.DeFi.only)
                }
                .padding([.vertical], Spacing.padding3)
                .padding([.horizontal], Spacing.padding2)
            }
            .cornerRadius(16.0, corners: .allCorners)
        }
        .padding(.horizontal, Spacing.padding2)
    }
}

// MARK: Provider

func provideDefiDashboard(
    tab: Tab,
    store: StoreOf<DashboardContent>
) -> some View {
    DeFiDashboardView(
        store: store.scope(
            state: \.defiState.home,
            action: DashboardContent.Action.defiHome
        )
    )
    .tag(tab.ref)
    .id(tab.ref.description)
    .accessibilityIdentifier(tab.ref.description)
}
