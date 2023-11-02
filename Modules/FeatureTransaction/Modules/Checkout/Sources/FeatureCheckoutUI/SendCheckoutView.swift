// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import FeatureCheckoutDomain
import SwiftUI

public struct SendCheckoutView<Object: LoadableObject>: View where Object.Output == SendCheckout, Object.Failure == Never {

    @BlockchainApp var app
    @Environment(\.context) var context

    @ObservedObject var viewModel: Object

    var confirm: (() -> Void)?

    public init(viewModel: Object, confirm: (() -> Void)? = nil) {
        _viewModel = .init(wrappedValue: viewModel)
        self.confirm = confirm
    }

    public var body: some View {
        AsyncContentView(
            source: viewModel,
            loadingView: Loading(),
            content: { Loaded(checkout: $0, confirm: confirm) }
        )
        .onAppear {
            app.post(
                event: blockchain.ux.transaction.checkout[].ref(to: context),
                context: context
            )
        }
    }
}

extension SendCheckoutView {

    public init<P>(
        publisher: P,
        confirm: (() -> Void)? = nil
    ) where P: Publisher, P.Output == SendCheckout, P.Failure == Never, Object == PublishedObject<P, DispatchQueue> {
        self.viewModel = PublishedObject(publisher: publisher)
        self.confirm = confirm
    }

    public init(
        _ checkout: Object.Output
    ) where Object == PublishedObject<Just<SendCheckout>, DispatchQueue> {
        self.init(publisher: Just(checkout))
    }
}

extension SendCheckoutView {

    public struct Loading: View {

        public var body: some View {
            ZStack {
                SendCheckoutView.Loaded(checkout: .preview)
                    .redacted(reason: .placeholder)
                ProgressView()
            }
        }
    }

    public struct Loaded: View {

        @BlockchainApp var app
        @Environment(\.context) var context
        @State private var isFirstResponder: Bool = false

        let checkout: SendCheckout
        let confirm: (() -> Void)?

        public init(checkout: SendCheckout, confirm: (() -> Void)? = nil) {
            self.checkout = checkout
            self.confirm = confirm
        }
    }
}

extension SendCheckoutView.Loaded {

    public var body: some View {
        VStack(alignment: .center, spacing: .zero) {
            List {
                Section {
                    rows()
                        .background(Color.semantic.background)
                } header: {
                    header()
                }
                if let memo = checkout.memo {
                    Section {
                        memoRow(memo: memo)
                    }
                    .background(Color.semantic.background)
                }
            }
            .tableRowBackground(Color.semantic.background)
            .listStyle(.insetGrouped)
            .hideScrollContentBackground()
            footer()
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationTitle(L10n.NavigationTitle.send.interpolating(checkout.currencyType.name))
        .background(Color.semantic.light.ignoresSafeArea())
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    func header() -> some View {
        HStack {
            Spacer()
            VStack(alignment: .center, spacing: Spacing.padding1) {
                if let mainValue = checkout.amountDisplayTitles.title {
                    Text(mainValue)
                        .typography(.title1)
                        .foregroundColor(.semantic.title)
                        .scaledToFit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                }
                Text(checkout.amountDisplayTitles.subtitle ?? "")
                    .typography(.body1)
                    .foregroundColor(.semantic.body)
                    .scaledToFit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.bottom, Spacing.padding3)
            .background(Color.clear)
            Spacer()
        }
        .background(Color.clear)
    }

    func rows() -> some View {
        Group {
            from()
            to()
            fees()
            total()
        }
        .listRowInsets(.zero)
        .frame(height: 80)
    }

    func from() -> some View {
        TableRow(
            title: .init(L10n.Label.from),
            trailingTitle: .init(checkout.from.name)
        )
    }

    func to() -> some View {
        TableRow(
            title: {
                HStack {
                    TableRowTitle(L10n.Label.to)
                    Icon.questionFilled
                        .micro()
                        .color(.semantic.text)
                }
            },
            trailing: {
                TableRowTitle(checkout.to.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 100)
            }
        )
        .onTapGesture {
            $app.post(
                event: blockchain.ux.transaction.send.address.info.entry.paragraph.row.tap,
                context: [
                    blockchain.ux.transaction.send.address.info.address: checkout.to.name,
                    blockchain.ui.type.action.then.enter.into.grabber.visible: true,
                    blockchain.ui.type.action.then.enter.into.detents: [
                        blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                    ]
                ]
            )
        }
        .batch {
            set(blockchain.ux.transaction.send.address.info.entry.paragraph.row.tap.then.enter.into, to: blockchain.ux.transaction.send.address.info)
        }
    }

    @ViewBuilder
    func fees() -> some View {
        switch checkout.fee.type {
        case .network:
            TableRow(
                title: .init(L10n.Label.networkFees),
                byline: { TagView(text: checkout.fee.type.tagTitle, variant: .outline) },
                trailingTitle: .init(checkout.fee.value.toDisplayString(includeSymbol: true)),
                trailingByline: .init(checkout.fee.exchange?.toDisplayString(includeSymbol: true) ?? "")
            )
        case .processing:
            TableRow(
                title: .init(L10n.Label.processingFees),
                trailingTitle: .init(checkout.fee.exchange?.toDisplayString(includeSymbol: true) ?? ""),
                trailingByline: .init(checkout.fee.value.toDisplayString(includeSymbol: true))
            )
        }
    }

    @ViewBuilder
    func total() -> some View {
        TableRow(
            title: .init(L10n.Label.total),
            trailingTitle: .init(checkout.totalDisplayTitles.title),
            trailingByline: .init(checkout.totalDisplayTitles.subtitle)
        )
    }

    @ViewBuilder
    func memoRow(memo: SendCheckout.Memo) -> some View {
        TableRow(
            title: L10n.Label.memo,
            footer: {
                VStack(alignment: .leading, spacing: Spacing.textSpacing) {
                    Text(memo.value ?? "")
                }
            }
        )
        .listRowInsets(.zero)
        .frame(minHeight: 100)
    }

    func footer() -> some View {
        VStack(spacing: .zero) {
            PrimaryButton(
                title: L10n.Button.confirm,
                action: {
                    app.post(
                        event: blockchain.ux.transaction.checkout.confirmed[].ref(to: context),
                        context: context
                    )
                    confirm?()
                }
            )
        }
        .padding()
        .background(Color.semantic.light)
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, Spacing.padding2)
            .padding(.horizontal, 12)
            .background(
                Color.semantic.light
            )
            .cornerRadius(Spacing.padding1)
    }
}

// MARK: Titles

extension SendCheckout {
    var amountDisplayTitles: (title: String?, subtitle: String?) {
        if isSourcePrivateKey {
            (
                amount.value.toDisplayString(includeSymbol: true),
                amount.fiatValue?.toDisplayString(includeSymbol: true)
            )
        } else {
            (
                amount.fiatValue?.toDisplayString(includeSymbol: true),
                amount.value.toDisplayString(includeSymbol: true)
            )
        }
    }

    var totalDisplayTitles: (title: String, subtitle: String) {
        if isSourcePrivateKey {
            (
                total.value.toDisplayString(includeSymbol: true),
                total.fiatValue?.toDisplayString(includeSymbol: true) ?? ""
            )
        } else {
            (
                total.fiatValue?.toDisplayString(includeSymbol: true) ?? "",
                total.value.toDisplayString(includeSymbol: true)
            )
        }
    }
}
