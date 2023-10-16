// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import FeatureDexData
import FeatureDexDomain
import SwiftUI

public struct DexMainView: View {

    let store: StoreOf<DexMain>
    @ObservedObject var viewStore: ViewStore<DexMain.State, DexMain.Action>
    @Environment(\.presentationMode) private var presentationMode
    @BlockchainApp var app

    public init(store: StoreOf<DexMain>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    public var body: some View {
        ScrollView {
            switch viewStore.status {
            case .notEligible:
                notEligible
            case .noBalance:
                noBalance
            case .loading:
                content
                    .redacted(reason: .placeholder)
                    .disabled(true)
            case .ready:
                content
            }
        }
        .background(Color.semantic.light.ignoresSafeArea())
        .onAppear {
            viewStore.send(.onAppear)
        }
        .onDisappear {
            viewStore.send(.onDisappear)
        }
        .bindings {
            subscribe(
                viewStore.$defaultFiatCurrency,
                to: blockchain.user.currency.preferred.fiat.trading.currency
            )
        }
        .bindings {
            subscribe(
                viewStore.$isEligible,
                to: blockchain.api.nabu.gateway.user.products.product["DEX"].is.eligible
            )
        }
        .bindings {
            subscribe(
                viewStore.$inegibilityReason,
                to: blockchain.api.nabu.gateway.user.products.product["DEX"].ineligible.message
            )
        }
        .bindings {
            subscribe(
                viewStore.$slippage,
                to: blockchain.ux.currency.exchange.dex.settings.slippage
            )
        }
        .bindings {
            subscribe(
                viewStore.$quoteByOutputEnabled,
                to: blockchain.ux.currency.exchange.dex.quote.by.output.is.enabled
            )
        }
        .bindings {
            subscribe(
                viewStore.$currentSelectedNetworkTicker,
                to: blockchain.ux.currency.exchange.dex.network.picker.selected.network.ticker.value
            )
        }
        .bindings {
            subscribe(
                viewStore.binding(
                    get: \.allowance.transactionHash,
                    send: {
                        .binding(.set(\.allowance.$transactionHash, $0))
                    }
                ),
                to: blockchain.ux.currency.exchange.dex.allowance.transactionId
            )
        }
        .batch {
            set(
                blockchain.ux.currency.exchange.dex.no.balance.tap.then.enter.into,
                to: blockchain.ux.currency.exchange.dex.no.balance.sheet
            )
            set(
                blockchain.ux.currency.exchange.dex.settings.tap.then.enter.into,
                to: blockchain.ux.currency.exchange.dex.settings.sheet
            )
            set(
                blockchain.ux.currency.exchange.dex.network.picker.tap.then.enter.into,
                to: blockchain.ux.currency.exchange.dex.network.picker.sheet
            )
            set(
                blockchain.ux.currency.exchange.dex.allowance.tap.then.enter.into,
                to: blockchain.ux.currency.exchange.dex.allowance.sheet
            )
        }
        .sheet(isPresented: viewStore.$isConfirmationShown, content: {
            IfLetStore(
                store.scope(state: \.confirmation, action: DexMain.Action.confirmationAction),
                then: { store in
                    PrimaryNavigationView {
                        DexConfirmationView(store: store)
                    }
                    .environment(\.navigationBarColor, .semantic.light)
                },
                else: { EmptyView() }
            )
        })
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Spacing.padding2) {
            Spacer()
                .frame(height: Spacing.padding1)
            quickActionsSection
            inputSection
            estimatedFee
                .padding(.top, Spacing.padding2)
            allowanceButton
            continueButton
            extraButton
            Spacer()
        }
        .padding(.horizontal, Spacing.padding2)
        .onTapGesture {
            viewStore.send(.dismissKeyboard)
        }
    }

    @ViewBuilder
    private var allowanceButton: some View {
        switch viewStore.state.allowance.status {
        case .notRequired, .unknown:
            EmptyView()
        case .complete:
            MinimalButton(
                title: String(format: L10n.Main.Allowance.approved, sourceDisplayCode),
                isOpaque: true,
                foregroundColor: .semantic.success,
                leadingView: {
                    Icon.checkCircle
                        .with(length: 24.pt)
                        .color(.semantic.success)
                },
                action: {}
            )
        case .pending:
            MinimalButton(
                title: "",
                isLoading: true,
                isOpaque: true,
                action: {}
            )
        case .required:
            MinimalButton(
                title: String(format: L10n.Main.Allowance.approve, sourceDisplayCode),
                isOpaque: true,
                action: { viewStore.send(.didTapAllowance) }
            )
        }
    }

    private var sourceDisplayCode: String {
        viewStore.source.currency?.displayCode ?? ""
    }

    @ViewBuilder
    private var extraButton: some View {
        switch viewStore.state.extraButtonState {
        case nil:
            EmptyView()
        case .deposit(let currency):
            MinimalButton(
                title: L10n.Main.depositMore.interpolating(currency.displayCode),
                isOpaque: true
            ) {
                app.post(
                    event: blockchain.ux.currency.receive.address.entry.paragraph.row.tap,
                    context: [
                        blockchain.ux.asset.id: currency.code,
                        blockchain.coin.core.account.id: currency.code,
                        blockchain.ui.type.action.then.enter.into.embed.in.navigation: false
                    ]
                )
            }
            .batch {
                set(
                    blockchain.ux.currency.receive.address.entry.paragraph.row.tap.then.enter.into,
                    to: blockchain.ux.currency.receive.address
                )
            }
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        switch viewStore.state.continueButtonState {
        case .noAssetOnNetwork(let network):
            AlertButton(
                title: viewStore.state.continueButtonState.title,
                action: {
                    let noBalance = blockchain.ux.currency.exchange.dex.no.balance
                    let detents = blockchain.ui.type.action.then.enter.into.detents
                    $app.post(
                        event: noBalance.tap,
                        context: [
                            noBalance.sheet.network: network.networkConfig.networkTicker,
                            detents: [detents.automatic.dimension]
                        ]
                    )
                }
            )
        case .error(let error):
            AlertButton(
                title: error.title,
                action: {
                    let detents = blockchain.ui.type.action.then.enter.into.detents
                    $app.post(
                        event: blockchain.ux.currency.exchange.dex.error.paragraph.button.alert.tap,
                        context: [
                            blockchain.ux.error: error,
                            detents: [detents.automatic.dimension]
                        ]
                    )
                }
            )
            .batch {
                set(blockchain.ux.currency.exchange.dex.error.paragraph.button.alert.tap.then.enter.into, to: blockchain.ux.error)
            }
        case .enterAmount, .previewSwapDisabled, .selectToken:
            SecondaryButton(
                title: viewStore.state.continueButtonState.title,
                action: {}
            )
            .disabled(true)
        case .previewSwap:
            PrimaryButton(title: viewStore.state.continueButtonState.title) {
                viewStore.send(.didTapPreview)
            }
        }
    }
}

extension DexMainView {

    private var estimatedFeeString: String {
        guard let networkFee = viewStore.quote?.success?.networkFee else {
            return viewStore.defaultFiatCurrency
                .flatMap(FiatValue.zero(currency:))?
                .displayString ?? ""
        }
        guard let exchangeRate = viewStore.networkNativePrice else {
            return networkFee.displayString
        }
        return networkFee.convert(using: exchangeRate).displayString
    }

    @ViewBuilder
    private var estimatedFeeIcon: some View {
        if viewStore.quoteFetching {
            ProgressView()
                .progressViewStyle(.indeterminate)
                .frame(width: 16.pt, height: 16.pt)
        } else {
            Icon.gas
                .color(.semantic.title)
                .micro()
        }
    }

    @ViewBuilder
    private var estimatedFeeLabel: some View {
        if !viewStore.quoteFetching {
            Text("~ \(estimatedFeeString)")
                .typography(.paragraph2)
                .foregroundColor(
                    viewStore.source.amount?.isZero ?? true ?
                        .semantic.body : .semantic.title
                )
        }
    }

    @ViewBuilder
    private var estimatedFeeTitle: some View {
        if viewStore.quoteFetching {
            Text(L10n.Main.fetchingPrice)
                .typography(.paragraph2)
                .foregroundColor(.semantic.title)
        } else {
            Text(L10n.Main.estimatedFee)
                .typography(.paragraph2)
                .foregroundColor(.semantic.title)
        }
    }

    @ViewBuilder
    private var estimatedFee: some View {
        HStack {
            HStack {
                estimatedFeeIcon
                estimatedFeeTitle
            }
            Spacer()
            estimatedFeeLabel
        }
        .padding(Spacing.padding2)
        .background(Color.semantic.background)
        .cornerRadius(Spacing.padding2)
    }
}

extension DexMainView {

    @ViewBuilder
    private var quickActionsSection: some View {
        HStack(spacing: Spacing.padding2) {
            netWorkPickerButton
            settingsButton
        }
    }

    @ViewBuilder
    private var netWorkPickerButton: some View {
        Button {
            viewStore.send(.onSelectNetworkTapped)
        } label: {
            HStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    Icon
                        .network
                        .small()
                        .color(.semantic.title)
                        .circle(backgroundColor: .semantic.light)

                    if let network = viewStore.currentNetwork {
                        network.logo(size: 12.pt)
                    }
                }
                .padding(.horizontal, Spacing.padding1)
                .padding(.vertical, Spacing.padding1)

                Text(L10n.Main.network)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)

                Spacer()

                Text(viewStore.currentNetwork?.networkConfig.shortName ?? "")
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.body)

                Icon
                    .chevronRight
                    .micro()
                    .color(.semantic.body)
                    .padding(.horizontal, Spacing.padding1)
            }
            .background(Color.semantic.background)
            .cornerRadius(16, corners: .allCorners)
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button {
            viewStore.send(.didTapSettings)
        } label: {
            VStack {
                Icon
                    .settings
                    .small()
                    .color(.semantic.title)
            }
            .padding(.horizontal, Spacing.padding2)
            .padding(.vertical, Spacing.padding1)
            .background(Color.semantic.background)
            .cornerRadius(16, corners: .allCorners)
        }
    }
}

extension DexMainView {

    @ViewBuilder
    private var inputSection: some View {
        ZStack {
            VStack {
                DexCellView(
                    store: store.scope(
                        state: \.source,
                        action: DexMain.Action.sourceAction
                    )
                )
                DexCellView(
                    store: store.scope(
                        state: \.destination,
                        action: DexMain.Action.destinationAction
                    )
                )
            }
            Button(
                action: {
                    if viewStore.quoteByOutputEnabled {
                        viewStore.send(.didTapFlip)
                    }
                },
                label: {
                    ZStack {
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color.semantic.light)
                        Icon.arrowDown
                            .small()
                            .color(.semantic.title)
                            .circle(backgroundColor: .semantic.background)
                    }
                }
            )
        }
    }
}

extension DexMainView {

    @ViewBuilder
    private var noBalanceCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Icon.coins.with(length: 88.pt)
                    .color(.semantic.title)
                    .circle(backgroundColor: .semantic.light)
                    .padding(8)

                ZStack {
                    Circle()
                        .frame(width: 54, height: 54)
                        .foregroundColor(Color.semantic.background)
                    Icon.walletReceive.with(length: 44.pt)
                        .color(.semantic.background)
                        .circle(backgroundColor: .semantic.primary)
                }
            }
            .padding(.top, Spacing.padding3)
            .padding(.horizontal, Spacing.padding2)

            Text(L10n.Main.NoBalance.title)
                .multilineTextAlignment(.center)
                .typography(.title3)
                .foregroundColor(.semantic.title)
                .padding(.horizontal, Spacing.padding2)
                .padding(.vertical, Spacing.padding1)

            Text(L10n.Main.NoBalance.body)
                .multilineTextAlignment(.center)
                .typography(.body1)
                .foregroundColor(.semantic.body)
                .padding(.horizontal, Spacing.padding2)

            PrimaryButton(title: L10n.Main.NoBalance.button, action: {
                $app.post(event: blockchain.ux.currency.exchange.dex.no.balance.show.receive.entry.paragraph.button.primary.tap)
            })
            .padding(.vertical, Spacing.padding3)
            .padding(.horizontal, Spacing.padding2)
        }
        .background(Color.semantic.background)
        .cornerRadius(Spacing.padding2)
        .padding(.horizontal, Spacing.padding3)
        .padding(.vertical, Spacing.padding3)
        .batch {
            set(
                blockchain.ux.currency.exchange.dex.no.balance.show.receive.entry.paragraph.button.primary.tap.then.enter.into,
                to: blockchain.ux.currency.receive.select.asset
            )
        }
    }

    @ViewBuilder
    private var noBalance: some View {
        VStack {
            noBalanceCard
            Spacer()
        }
    }
}

extension DexMainView {

    @ViewBuilder
    private var notEligibleCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Icon.walletSwap.with(length: 88.pt)
                    .color(.semantic.title)
                    .circle(backgroundColor: .semantic.light)
                    .padding(8)

                Icon.alert
                    .with(length: 44.pt)
                    .iconColor(.semantic.warning)
                    .background(
                        Circle().fill(Color.semantic.background)
                            .frame(width: 59.pt, height: 59.pt)
                    )
            }
            .padding(.top, Spacing.padding3)
            .padding(.horizontal, Spacing.padding2)

            Text(L10n.Main.NotEligible.title)
                .multilineTextAlignment(.center)
                .typography(.title3)
                .foregroundColor(.semantic.title)
                .padding(.horizontal, Spacing.padding2)
                .padding(.vertical, Spacing.padding1)

            Text(viewStore.inegibilityReason ?? "")
                .multilineTextAlignment(.center)
                .typography(.body1)
                .foregroundColor(.semantic.body)
                .padding(.horizontal, Spacing.padding2)

            MinimalButton(title: L10n.Main.NotEligible.button, action: {
                viewStore.send(.onInegibilityLearnMoreTap)
            })
            .padding(.vertical, Spacing.padding3)
            .padding(.horizontal, Spacing.padding2)
        }
        .background(Color.semantic.background)
        .cornerRadius(Spacing.padding2)
        .padding(.horizontal, Spacing.padding3)
        .padding(.vertical, Spacing.padding3)
    }

    @ViewBuilder
    private var notEligible: some View {
        VStack {
            notEligibleCard
            Spacer()
        }
    }
}

struct DexMainView_Previews: PreviewProvider {

    private static var app = App.preview.withPreviewData()

    static var usdt: CryptoCurrency! {
        _ = app
        return EnabledCurrenciesService.default
            .allEnabledCryptoCurrencies
            .first(where: { $0.code == "USDT" })
    }

    typealias State = (String, DexMain.State, DexService)

    static func dexService(
        with service: DexAllowanceRepositoryAPI
    ) -> DexService {
        withDependencies { dependencies in
            dependencies.dexAllowanceRepository = allowanceRepository
        } operation: {
            DexService.preview
        }
    }

    static var allowanceRepository: DexAllowanceRepositoryAPI {
        DexAllowanceRepositoryDependencyKey.noAllowance
    }

    static var states: [State] = [
        (
            "Default", DexMain.State(), dexService(with: allowanceRepository)
        ),
        (
            "Not enough ETH",
            DexMain.State().setup { state in
                state.source.balance = DexBalance(
                    value: .create(major: 1.0, currency: usdt)
                )
                state.source.inputText = "2"
            },
            dexService(with: allowanceRepository)
        ),
        (
            "Not enough ETH for gas fees",
            DexMain.State().setup { state in
                state.source.balance = DexBalance(
                    value: .create(major: 2.0, currency: usdt)
                )
                state.source.inputText = "1"
                state.quote = Result<DexQuoteOutput, UX.Error>.failure(DexUXError.insufficientFunds(usdt))
            },
            dexService(with: allowanceRepository).setup { service in
                service.quote = { _ in .just(.failure(.mockUxError)) }
            }
        )
    ]

    static var previews: some View {
        ForEach(states, id: \.0) { label, state, dexService in
            PrimaryNavigationView {
                DexMainView(
                    store: Store(
                        initialState: state,
                        reducer: {
                            withDependencies { dependencies in
                                dependencies.dexService = dexService
                                dependencies.app = app
                            } operation: {
                                DexMain()
                                    ._printChanges()
                            }
                        }
                    )
                )
                .app(app)
            }
            .previewDisplayName(label)
        }
    }
}

extension UX.Error {
    static let mockUxError = UX.Error(
        title: "This is a title for a mock UX.Error",
        message: "This is the message to the user."
    )
}
