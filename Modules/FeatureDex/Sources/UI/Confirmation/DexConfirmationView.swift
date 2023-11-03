// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import FeatureDexDomain
import SwiftUI

struct DexConfirmationView: View {

    static let axlUSDC = "axlUSDC"
    typealias L10n = FeatureDexUI.L10n.Confirmation

    let store: StoreOf<DexConfirmation>
    @ObservedObject var viewStore: ViewStore<DexConfirmation.State, DexConfirmation.Action>
    @Environment(\.presentationMode) private var presentationMode
    @BlockchainApp var app

    init(store: StoreOf<DexConfirmation>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    @ViewBuilder
    var body: some View {
        Group {
            VStack(alignment: .center) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 24) {
                        swap
                            .padding(.top, Spacing.padding2)
                        rows
                        disclaimer
                    }
                }
                .padding(.horizontal)
                Spacer()
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.semantic.light.ignoresSafeArea())
            PrimaryNavigationLink(
                destination: pendingTransactionView,
                isActive: viewStore.$didConfirm,
                label: EmptyView.init
            )
        }
        .primaryNavigation(
            title: L10n.title,
            trailing: { closeButton }
        )
    }

    @ViewBuilder
    private var pendingTransactionView: some View {
        IfLet(viewStore.$pendingTransaction, then: { $state in
            PendingTransactionView(
                state: state,
                dismiss: { presentationMode.wrappedValue.dismiss() }
            )
        })
    }

    @ViewBuilder
    private var closeButton: some View {
        IconButton(icon: .navigationCloseButton()) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    @ViewBuilder
    private var swap: some View {
        ZStack {
            VStack {
                DexConfirmationTargetView(
                    value: viewStore.quote.from,
                    balance: viewStore.sourceBalance
                )
                DexConfirmationTargetView(
                    value: viewStore.quote.to,
                    balance: viewStore.destinationBalance
                )
            }
            Icon.arrowDown
                .small()
                .color(.semantic.title)
                .circle(backgroundColor: .semantic.background)
                .background(Circle().fill(Color.semantic.light).scaleEffect(1.5))
        }
    }

    @ViewBuilder
    private var rows: some View {
        DividedVStack {
            if let value = viewStore.quote.estimatedConfirmationTime {
                tableRow(
                    title: L10n.estimatedConfirmationTime,
                    value: {
                        tableRowTitle("\(value)s")
                    },
                    tooltip: nil
                )
            }
            tableRow(
                title: L10n.allowedSlippage,
                value: {
                    tableRowTitle(formatSlippage(viewStore.quote.slippage))
                },
                tooltip: nil
            )
            tableRow(
                title: L10n.blockchainFee,
                value: {
                    tableRowTitle(formatSlippage(viewStore.quote.blockchainFee))
                },
                tooltip: (L10n.SlippageTooltip.title, L10n.SlippageTooltip.body)
            )
            tableRow(
                title: L10n.exchangeRate,
                value: {
                    tableRowTitle("\(viewStore.quote.exchangeRate.base.displayString) = \(viewStore.quote.exchangeRate.quote.displayString)")
                },
                tooltip: nil
            )
            tableRow(
                title: L10n.minAmount,
                value: {
                    ValueWithQuoteView(value: viewStore.quote.minimumReceivedAmount, isEstimated: false)
                },
                tooltip: (title: L10n.MinAmountTooltip.title, message: L10n.MinAmountTooltip.body)
            )
        }
        .padding(.vertical, 6.pt)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic.background)
        )
        feeRows
    }

    @ViewBuilder
    private var feeRows: some View {
        DividedVStack {
            ForEach(viewStore.quote.fees.indexed(), id: \.index) { _, fee in
                tableRow(
                    title: fee.title,
                    value: {
                        ValueWithQuoteView(value: fee.value, isEstimated: true)
                    },
                    tooltip: fee.tooltip
                )
            }
        }
        .padding(.vertical, 6.pt)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic.background)
        )
    }

    @ViewBuilder
    private var disclaimer: some View {
        VStack(alignment: .center, spacing: Spacing.padding2) {
            regularDisclaimer
            if viewStore.quote.axelarCrossChainQuote {
                axelarCrossChainDisclaimer
            }
        }
    }

    @ViewBuilder
    private var axelarCrossChainDisclaimer: some View {
        Text(L10n.crossChainRevertDisclaimer.interpolating(Self.axlUSDC))
            .typography(.caption1)
            .foregroundColor(.semantic.body)
            .multilineTextAlignment(.center)
        SmallSecondaryButton(title: L10n.learnMore) {
            $app.post(
                event: blockchain.ux.tooltip.entry.paragraph.button.minimal.tap,
                context: [
                    blockchain.ux.tooltip.title: L10n.CrossChainRevertTooltip.title,
                    blockchain.ux.tooltip.body: L10n.CrossChainRevertTooltip.body.interpolating(Self.axlUSDC),
                    blockchain.ui.type.action.then.enter.into.detents: [
                        blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                    ]
                ]
            )
        }
        Image("axelar-dex-logo", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 40.pt)
            .padding(.bottom, Spacing.padding1)
    }

    private var regularDisclaimerText: String {
        L10n.revertDisclaimer.interpolating(viewStore.quote.minimumReceivedAmount.displayString)
    }

    @ViewBuilder
    private var regularDisclaimer: some View {
        Text(regularDisclaimerText)
            .typography(.caption1)
            .foregroundColor(.semantic.body)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Spacing.padding2) {
            if viewStore.priceUpdated {
                HStack {
                    Icon.error.color(.semantic.warning).small()
                    Text(L10n.priceUpdated)
                        .typography(.paragraph2)
                        .foregroundColor(.semantic.title)
                    Spacer()
                    SmallPrimaryButton(title: L10n.accept) {
                        viewStore.send(.acceptPrice, animation: .linear)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.semantic.light)
                )
            }
            Group {
                if viewStore.quote.enoughBalance {
                    PrimaryButton(title: L10n.swap) {
                        viewStore.send(.confirm)
                    }
                    .disabled(viewStore.priceUpdated)
                } else {
                    Text(L10n.notEnoughBalance.interpolating(viewStore.quote.from.currency.displayCode))
                        .typography(.caption1)
                        .foregroundColor(.semantic.warning)
                    AlertButton(
                        title: L10n.notEnoughBalanceButton.interpolating(viewStore.quote.from.currency.displayCode),
                        action: {}
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic.background)
                .ignoresSafeArea(edges: .bottom)
        )
        .batch {
            set(blockchain.ux.tooltip.entry.paragraph.button.minimal.tap.then.enter.into, to: blockchain.ux.tooltip)
        }
    }

    @ViewBuilder
    private func tableRowTitle(_ string: String) -> some View {
        TableRowTitle(string)
            .lineLimit(1)
            .minimumScaleFactor(0.1)
    }

    @ViewBuilder
    private func tableRow(
        title: String,
        value: () -> some View,
        tooltip: (title: String, message: String)?
    ) -> some View {
        TableRow(
            title: {
                HStack {
                    TableRowTitle(title)
                        .foregroundColor(.semantic.body)
                    if tooltip != nil {
                        Icon.questionFilled
                            .micro()
                            .color(.semantic.muted)
                    }
                }
            },
            trailing: value
        )
        .tableRowVerticalInset(Spacing.padding2)
        .onTapGesture {
            if let (title, body) = tooltip {
                $app.post(
                    event: blockchain.ux.tooltip.entry.paragraph.button.minimal.tap,
                    context: [
                        blockchain.ux.tooltip.title: title,
                        blockchain.ux.tooltip.body: body,
                        blockchain.ui.type.action.then.enter.into.detents: [
                            blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                        ]
                    ]
                )
            }
        }
    }

    struct ValueWithQuoteView: View {
        let value: CryptoValue
        let isEstimated: Bool
        @State var exchangeRate: MoneyValue?

        var body: some View {
            VStack(alignment: .trailing) {
                TableRowTitle(title)
                if let byline {
                    TableRowByline(byline)
                }
            }
            .bindings {
                subscribe(
                    $exchangeRate,
                    to: blockchain.api.nabu.gateway.price.crypto[value.code].fiat.quote.value
                )
            }
        }

        private var byline: String? {
            guard let exchangeRate else {
                return nil
            }
            let string = value.convert(using: exchangeRate).displayString
            return isEstimated ? "~ \(string)" : string
        }

        private var title: String {
            isEstimated ? "~ \(value.displayString)" : value.displayString
        }
    }
}

extension DexQuoteOutput.Fee {
    fileprivate var title: String {
        switch type {
        case .express:
            return L10n.Confirmation.expressFee
        case .network:
            return L10n.Confirmation.networkFee
        case .crossChain:
            return L10n.Confirmation.crossChainNetworkFee
        case .total:
            return L10n.Confirmation.totalFee
        }
    }

    fileprivate var tooltip: (title: String, message: String)? {
        switch type {
        case .network:
            return (
                L10n.Confirmation.networkFee,
                L10n.Confirmation.networkFeeDescription.interpolating(value.displayCode)
            )
        case .crossChain:
            return (
                L10n.Confirmation.crossChainNetworkFee,
                L10n.Confirmation.networkFeeDescription.interpolating(value.displayCode)
            )
        case .express:
            return nil
        case .total:
            return nil
        }
    }
}

struct DexConfirmationView_Previews: PreviewProvider {

    static var app: AppProtocol = App.preview.withPreviewData()

    @ViewBuilder
    static var previews: some View {
        DexConfirmationView(
            store: Store(
                initialState: .preview,
                reducer: { DexConfirmation(app: app) }
            )
        )
        .app(app)
        .previewDisplayName("Confirmation")

        DexConfirmationView(
            store: Store(
                initialState: .preview,
                reducer: { DexConfirmation(app: app) }
            )
        )
        .app(app)
        .previewDisplayName("Price updated")

        DexConfirmationView(
            store: Store(
                initialState: .preview.setup { state in
                    state.quote.enoughBalance = false
                },
                reducer: { DexConfirmation(app: app) }
            )
        )
        .app(app)
        .previewDisplayName("Not enough balance")
    }
}
