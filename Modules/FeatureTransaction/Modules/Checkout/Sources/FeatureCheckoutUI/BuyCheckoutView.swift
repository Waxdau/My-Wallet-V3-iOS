import BlockchainUI
import Localization
import SwiftUI

typealias L10n = LocalizationConstants.Checkout

public struct BuyCheckoutView<Object: LoadableObject>: View where Object.Output == BuyCheckout, Object.Failure == Never {

    @BlockchainApp var app
    @Environment(\.context) var context

    @ObservedObject var viewModel: Object
    private var confirm: (() -> Void)?

    public init(viewModel: Object, confirm: (() -> Void)? = nil) {
        _viewModel = .init(wrappedValue: viewModel)
        self.confirm = confirm
    }

    public var body: some View {
        AsyncContentView(
            source: viewModel,
            loadingView: Loading(),
            content: {
                Loaded(checkout: $0, confirm: confirm)
            }
        )
        .onAppear {
            app.post(
                event: blockchain.ux.transaction.checkout[].ref(to: context),
                context: context
            )
        }
    }
}

extension BuyCheckoutView {

    public init<P>(publisher: P, confirm: (() -> Void)? = nil) where P: Publisher, P.Output == BuyCheckout, P.Failure == Never, Object == PublishedObject<P, DispatchQueue> {
        self.viewModel = PublishedObject(publisher: publisher)
        self.confirm = confirm
    }

    public init(_ checkout: Object.Output) where Object == PublishedObject<Just<BuyCheckout>, DispatchQueue> {
        self.init(publisher: Just(checkout))
    }
}

extension BuyCheckoutView {

    public struct Loading: View {

        public var body: some View {
            ZStack {
                BuyCheckoutView.Loaded(checkout: .preview)
                    .redacted(reason: .placeholder)
                ProgressView()
            }
        }
    }

    public struct Loaded: View {

        @BlockchainApp var app
        @Environment(\.context) var context
        @Environment(\.openURL) var openURL

        @State var isAvailableToTradeInfoPresented = false
        @State var isACHTermsInfoPresented = false
        @State var isInvestWeeklySelected = false
        @State private var isExternalTradingEnabled: Bool = false
        @State private var isRecurringBuyEnabled: Bool = true

        let checkout: BuyCheckout
        let confirm: (() -> Void)?

        @State var information = (price: false, fee: false)
        @State var remaining: TimeInterval = Int.max.d

        public init(checkout: BuyCheckout, confirm: (() -> Void)? = nil) {
            self.checkout = checkout
            self.confirm = confirm
        }

        init(checkout: BuyCheckout, information: (Bool, Bool) = (false, false), confirm: (() -> Void)? = nil) {
            self.checkout = checkout
            _information = .init(wrappedValue: information)
            self.confirm = confirm
        }
    }
}

extension BuyCheckoutView.Loaded {

    public var body: some View {
        VStack(alignment: .center, spacing: .zero) {
            ScrollView {
                Group {
                    header()
                    if isExternalTradingEnabled {
                        bakktRows()
                        bakktBottomView()
                    } else {
                        rows()
                        quoteExpiry()
                        disclaimer()
                    }
                }
                .padding(.horizontal)
            }
            footer()
        }
        .background(Color.semantic.light.ignoresSafeArea())
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bottomSheet(isPresented: $isAvailableToTradeInfoPresented) {
            availableToTradeInfoSheet
        }
        .sheet(isPresented: $isACHTermsInfoPresented) {
            achTermsInfoSheet
        }
        .bindings {
            subscribe($isExternalTradingEnabled, to: blockchain.app.is.external.brokerage)
            subscribe($isRecurringBuyEnabled, to: blockchain.app.configuration.recurring.buy.is.enabled)
        }
    }

    @ViewBuilder func header() -> some View {
        HStack {
            Spacer()
            VStack(alignment: .center, spacing: Spacing.padding1) {
                Text(checkout.fiat.displayString)
                    .typography(.title1)
                    .foregroundColor(.semantic.title)
                    .minimumScaleFactor(0.7)
                HStack(spacing: .zero) {
                    Text(checkout.crypto.displayString)
                        .typography(.body1)
                        .foregroundColor(.semantic.body)
                }
            }
            Spacer()
        }
        .padding(.vertical)
    }

    // views to display for bakkt buy checkout view
    @ViewBuilder func bakktRows() -> some View {
        DividedVStack {
            price(toolTipInfoEnabled: false)
            paymentMethod()
            bakktPurchaseAmount()
            availableDates()
        }
        .padding(.vertical, 8.pt)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic.background)
        )
    }

    @ViewBuilder func rows() -> some View {
        DividedVStack {
            price(toolTipInfoEnabled: true)
            paymentMethod()
            purchaseAmount()
            fees()
            recurringBuyFrequency()
            checkoutTotal()
            availableDates()
            investWeekly()
        }
        .padding(.vertical, 8.pt)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic.background)
        )
    }

    @ViewBuilder func checkoutTotal() -> some View {
        TableRow(
            title: TableRowTitle(L10n.Label.total).foregroundColor(.semantic.body),
            trailing: {
                TableRowTitle(checkout.total.displayString)
            }
        )
    }

    @ViewBuilder func paymentMethod() -> some View {
        TableRow(
            title: TableRowTitle(L10n.Label.paymentMethod).foregroundColor(.semantic.body),
            trailing: {
                VStack(alignment: .trailing, spacing: .zero) {
                    TableRowTitle(checkout.paymentMethod.name)
                    if let detail = checkout.paymentMethod.detail {
                        TableRowByline(detail)
                    }
                }
            }
        )
    }

    @ViewBuilder func purchaseAmount() -> some View {
        TableRow(
            title: TableRowTitle(L10n.Label.purchase).foregroundColor(.semantic.body),
            trailing: {
                VStack(alignment: .trailing, spacing: .zero) {
                    TableRowTitle(checkout.fiat.displayString)
                    TableRowByline(checkout.crypto.displayString)
                }
            }
        )
    }

    @ViewBuilder func bakktPurchaseAmount() -> some View {
        TableRow(
            title: TableRowTitle(L10n.Label.purchase).foregroundColor(.semantic.body),
            trailing: {
                VStack(alignment: .trailing, spacing: .zero) {
                    TableRowTitle("~\(checkout.crypto.displayString)")
                }
            }
        )
    }

    @ViewBuilder var availableToTradeInfoSheet: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack {
                Text(L10n.AvailableToTradeInfo.title)
                    .typography(.body2)
                    .foregroundColor(.semantic.body)
                Spacer()
                IconButton(icon: .close.circle()) {
                    isAvailableToTradeInfoPresented = false
                }
                .frame(width: 24.pt, height: 24.pt)
            }

            VStack(alignment: .leading, spacing: Spacing.padding2) {
                Text(L10n.AvailableToTradeInfo.description)
                    .typography(.body1)
                    .foregroundColor(Color.semantic.text)
                SmallMinimalButton(title: L10n.AvailableToTradeInfo.learnMoreButton) {
                    isAvailableToTradeInfoPresented = false
                    Task { @MainActor in
                        try await openURL(app.get(blockchain.ux.transaction["buy"].checkout.terms.of.withdraw))
                    }
                }
            }
        }
        .padding(Spacing.padding3)
    }

    @ViewBuilder var achTermsInfoSheet: some View {
        PrimaryNavigationView {
            VStack {
                ScrollView {
                    Text(checkout.achTermsInfoDescriptionText)
                        .fixedSize(horizontal: false, vertical: true)
                        .typography(.body1)
                        .foregroundColor(.semantic.text)
                }
                PrimaryButton(title: L10n.ACHTermsInfo.doneButton) {
                    isACHTermsInfoPresented = false
                }
                .frame(alignment: .bottom)
            }
            .primaryNavigation(
                title: L10n.ACHTermsInfo.title,
                trailing: {
                    IconButton(icon: .close.circle()) {
                        isACHTermsInfoPresented = false
                    }
                    .frame(width: 24.pt, height: 24.pt)
                }
            )
            .padding([.horizontal, .bottom], Spacing.padding3)
            .padding(.top, Spacing.padding1)
        }
    }

    @ViewBuilder func price(toolTipInfoEnabled: Bool) -> some View {
        VStack {
            TableRow(
                title: {
                    HStack {
                        TableRowTitle(L10n.Label.price(checkout.crypto.code)).foregroundColor(.semantic.body)
                        if toolTipInfoEnabled {
                            Icon.questionFilled
                                .micro().color(.semantic.muted)
                        }
                    }
                },
                trailing: {
                    TableRowTitle(checkout.exchangeRate.displayString)
                }
            )
            .background(Color.semantic.background)
            .onTapGesture {
                withAnimation {
                    if toolTipInfoEnabled {
                        information.price.toggle()
                    }
                }
            }
            if information.price {
                explain(L10n.Label.priceDisclaimer)
            }
        }
    }

    @ViewBuilder func fees() -> some View {
        if let fee = checkout.fee {
            VStack {
                TableRow(
                    title: {
                        HStack {
                            TableRowTitle(L10n.Label.blockchainFee).foregroundColor(.semantic.body)
                            Icon.questionFilled
                                .micro()
                                .color(.semantic.muted)
                        }
                    },
                    trailing: {
                        if let promotion = fee.promotion, promotion != fee.value {
                            VStack {
                                TagView(
                                    text: promotion.isZero ? L10n.Label.free : promotion.displayString,
                                    variant: .success,
                                    size: .small
                                )
                                Text(rich: "~~\(fee.value.displayString)~~")
                                    .typography(.paragraph1)
                                    .foregroundColor(.semantic.text)
                            }
                        } else if fee.value.isZero {
                            TagView(text: L10n.Label.free, variant: .success, size: .large)
                        } else {
                            TableRowTitle(fee.value.displayString)
                        }
                    }
                )
                .background(Color.semantic.background)
                .onTapGesture {
                    withAnimation { information.fee.toggle() }
                }
                if fee.value.isNotZero, information.fee {
                    explain(L10n.Label.custodialFeeDisclaimer)
                }
            }
        }
    }

    @ViewBuilder func recurringBuyFrequency() -> some View {
        if let recurringBuyDetails = checkout.recurringBuyDetails, isRecurringBuyEnabled {
            TableRow(
                title: TableRowTitle(LocalizationConstants.Transaction.Confirmation.frequency).foregroundColor(.semantic.body),
                trailing: {
                    VStack(alignment: .trailing, spacing: .zero) {
                        TableRowTitle(recurringBuyDetails.frequency)
                        if let description = recurringBuyDetails.description {
                            TableRowByline(description)
                        }
                    }
                }
            )
        }
    }

    @ViewBuilder func availableDates() -> some View {
        if let availableToTrade = checkout.depositTerms?.availableToTrade {
            TableRow(
                title: TableRowTitle(LocalizationConstants.Transaction.Confirmation.availableToTrade).foregroundColor(.semantic.body),
                trailing: {
                    TableRowTitle(availableToTrade)
                }
            )
        }

        if let availableToWithdraw = checkout.depositTerms?.availableToWithdraw {
            TableRow(
                title: {
                    HStack {
                        TableRowTitle(LocalizationConstants.Transaction.Confirmation.availableToWithdraw).foregroundColor(.semantic.body)
                        Icon
                            .questionFilled
                            .micro()
                            .color(.semantic.muted)
                    }
                },
                trailing: {
                    TableRowTitle(availableToWithdraw)
                }
            )
            .background(Color.semantic.background)
            .onTapGesture {
                isAvailableToTradeInfoPresented.toggle()
            }
        }
    }

    @ViewBuilder func bakktBottomView() -> some View {
        VStack {
            VStack(alignment: .leading) {
                bakktDisclaimer()
                SmallMinimalButton(title: L10n.Button.viewDisclosures) {
                    $app.post(event: blockchain.ux.bakkt.view.disclosures)
                }
                .batch {
                    set(blockchain.ux.bakkt.view.disclosures.then.launch.url, to: "https://bakkt.com/disclosures")
                }
            }

            bakktAlertCard()
                .padding(.vertical, Spacing.padding2)

            Image("bakkt-logo", bundle: .componentLibrary)
                .foregroundColor(.semantic.title)
        }
    }

    @ViewBuilder
    func bakktDisclaimer() -> some View {
        let label = L10n.Label.buyDisclaimerBakkt(
            fiatAmount: checkout.fiat.displayString,
            amount: checkout.crypto.displayString,
            asset: checkout.crypto.currency.code
        )

        Text(rich: label)
            .typography(.caption1)
            .foregroundColor(.semantic.body)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.padding1)
            .padding(.top, Spacing.padding3)
            .onTapGesture {
                $app.post(event: blockchain.ux.bakkt.authorization)
            }
            .batch {
                set(blockchain.ux.bakkt.authorization.then.launch.url, to: { blockchain.ux.bakkt.authorization.url })
            }
    }

    @ViewBuilder
    func bakktAlertCard() -> some View {
        AlertCard(
            title: L10n.Label.bakktAlertTitle,
            message: L10n.Label.bakktAlertSubTitle,
            variant: .warning,
            isBordered: false,
            backgroundColor: .semantic.background
        )
    }

    @ViewBuilder
    func investWeekly() -> some View {
        if checkout.displaysInvestWeekly, isRecurringBuyEnabled {
            TableRow(
                title: { TableRowTitle(L10n.Label.investWeeklyTitle).foregroundColor(.semantic.body) },
                trailing: {
                    Toggle(isOn: $isInvestWeeklySelected) {
                        EmptyView()
                    }
                    .toggleStyle(.switch)
                },
                footer: {
                    Text(String(format: L10n.Label.investWeeklySubtitle, checkout.total.displayString))
                        .typography(.caption1)
                        .foregroundColor(.semantic.body)
                }
            )
            .onChange(of: isInvestWeeklySelected) { newValue in
                $app.post(value: newValue, of: blockchain.ux.transaction.checkout.recurring.buy.invest.weekly)
            }
        }
    }

    @ViewBuilder
    func explain(_ content: some StringProtocol) -> some View {
        Text(rich: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.semantic.text)
            .multilineTextAlignment(.leading)
            .typography(.caption1)
            .transition(.scale.combined(with: .opacity))
            .padding()
            .background(Color.semantic.light)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding([.leading, .trailing], 8.pt)
    }

    @ViewBuilder func disclaimer() -> some View {
        VStack(alignment: .leading) {
            if checkout.paymentMethod.isACH {
                VStack(alignment: .leading, spacing: Spacing.padding2) {
                    Text(checkout.achTransferDisclaimerText)
                    .multilineTextAlignment(.leading)
                    SmallMinimalButton(title: L10n.AchTransferDisclaimer.readMoreButton) {
                        isACHTermsInfoPresented = true
                    }
                }
            } else {
                Text(rich: L10n.Label.indicativeDisclaimer)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(rich: L10n.Label.termsOfService)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        $app.post(event: blockchain.ux.transaction.checkout.terms.of.service)
                    }
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .typography(.caption1)
        .foregroundColor(.semantic.text)
        .batch {
            set(blockchain.ux.transaction.checkout.terms.of.service.then.launch.url, to: { blockchain.ux.transaction.checkout.terms.of.service.url })
        }
    }

    @ViewBuilder func quoteExpiry() -> some View {
        if let expiration = checkout.quoteExpiration {
            CountdownView(deadline: expiration, remainingTime: $remaining)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.semantic.background)
                )
        }
    }

    func confirmed() {
        app.post(
            event: blockchain.ux.transaction.checkout.confirmed[].ref(to: context),
            context: context
        )
        confirm?()
    }

    @ViewBuilder
    func footer() -> some View {
        VStack(spacing: .zero) {
            if let recurringBuyDetails = checkout.recurringBuyDetails, isRecurringBuyEnabled {
                PrimaryButton(
                    title: L10n.Button.buy(checkout.crypto.code) + " \(recurringBuyDetails.frequency)",
                    isLoading: remaining <= 3,
                    action: confirmed
                )
                .disabled(remaining <= 3)
            } else if checkout.paymentMethod.isApplePay {
                ApplePayButton(action: confirmed)
            } else {
                PrimaryButton(
                    title: L10n.Button.buy(checkout.crypto.code),
                    isLoading: remaining <= 3,
                    action: confirmed
                )
                .disabled(remaining <= 3)
            }
        }
        .padding()
        .background(Rectangle().fill(Color.semantic.background).ignoresSafeArea())
    }
}

struct BuyCheckoutView_Previews: PreviewProvider {

    static var previews: some View {
        PrimaryNavigationView {
            BuyCheckoutView(.preview)
                .primaryNavigation(title: "Checkout")
        }
        .environment(\.navigationBarColor, .semantic.light)
        .app(App.preview)
        .previewDisplayName("Default")

        PrimaryNavigationView {
            BuyCheckoutView(.promotion)
                .primaryNavigation(title: "Checkout")
        }
        .environment(\.navigationBarColor, .semantic.light)
        .app(App.preview)
        .previewDisplayName("Fee Promo")

        PrimaryNavigationView {
            BuyCheckoutView(.free)
                .primaryNavigation(title: "Checkout")
        }
        .environment(\.navigationBarColor, .semantic.light)
        .app(App.preview)
        .previewDisplayName("Free Fees")
    }
}

extension BuyCheckout {

    static var promotion = { checkout in
        var checkout = checkout
        checkout.purchase = MoneyValuePair(
            fiatValue: .create(major: 99.51, currency: .USD),
            exchangeRate: .create(major: 47410.61, currency: .USD),
            cryptoCurrency: .bitcoin,
            usesFiatAsBase: true
        )
        checkout.fee?.promotion = FiatValue.create(minor: "49", currency: .USD)
        return checkout
    }(BuyCheckout.preview)

    static var free = { checkout in
        var checkout = checkout
        checkout.purchase = MoneyValuePair(
            fiatValue: .create(major: 100.00, currency: .USD),
            exchangeRate: .create(major: 47410.61, currency: .USD),
            cryptoCurrency: .bitcoin,
            usesFiatAsBase: true
        )
        checkout.fee?.promotion = FiatValue.create(minor: "0", currency: .USD)
        return checkout
    }(BuyCheckout.preview)
}

#if canImport(PassKit)

import PassKit

private struct _ApplePayButton: UIViewRepresentable {
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    func makeUIView(context: Context) -> PKPaymentButton {
        PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .automatic)
    }
}

struct ApplePayButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View { _ApplePayButton().frame(maxHeight: 44.pt) }
}

struct ApplePayButton: View {

    var button: Button<EmptyView>

    init(action: @escaping () -> Void) {
        self.button = Button(action: action, label: EmptyView.init)
    }

    var body: some View {
        button.buttonStyle(ApplePayButtonStyle())
    }
}
#endif

extension BuyCheckout {
    private var paymentMethodLabel: String {
        [paymentMethod.name, paymentMethod.detail].compactMap { $0 }.joined(separator: " ")
    }

    fileprivate var achTermsInfoDescriptionText: String {
        let description: String = {
            switch buyType {
            case .simpleBuy:
                return L10n.ACHTermsInfo.simpleBuyDescription
            case .recurringBuy:
                return L10n.ACHTermsInfo.recurringBuyDescription
            }
        }()
        return String(
            format: description,
            paymentMethodLabel,
            total.displayString,
            depositTerms?.withdrawalLockInDays ?? ""
        )
    }

    fileprivate var achTransferDisclaimerText: String {
        switch buyType {
        case .simpleBuy:
            return String(
                format: L10n.AchTransferDisclaimer.simpleBuyDescription,
                total.displayString,
                crypto.code,
                exchangeRate.displayString
            )
        case .recurringBuy:
            return String(
                format: L10n.AchTransferDisclaimer.recurringBuyDescription,
                paymentMethodLabel,
                total.displayString
            )
        }
    }
}
