import Blockchain
import SwiftUI

public struct MoneyValueView: View {

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.typography) var typography
    @Environment(\.context) var context

    @State private var isHidingBalance = false

    let value: MoneyValue

    public init(_ value: MoneyValue) {
        self.value = value
    }

    public var body: some View {
        Text(isRedacted ? redacted : value.displayString)
            .typography(typography.slashedZero())
            .bindings {
                if context[blockchain.ux.dashboard.is.hiding.balance].isNil {
                    subscribe($isHidingBalance, to: blockchain.ux.dashboard.is.hiding.balance)
                }
            }
    }

    var isRedacted: Bool {
        if let isHidingBalance = context[blockchain.ux.dashboard.is.hiding.balance] as? Bool {
            return isHidingBalance
        }
        return isHidingBalance || redactionReasons.contains(.privacy)
    }

    var redacted: String {
        value.displayString.hasPrefix(value.displaySymbol) ? "\(value.displaySymbol) ••••" : "•••• \(value.displaySymbol)"
    }
}

public struct MoneyValueAndQuoteView: View {

    @Environment(\.moneyValueViewQuoteCurrency) private var quoteCurrency

    let value: MoneyValue
    let alignment: HorizontalAlignment

    @State private var quoteValue: MoneyValue?

    public init(_ value: MoneyValue, alignment: HorizontalAlignment = .trailing) {
        self.value = value
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            if let quoteValue, quoteValue.currency != value.currency {
                value.convert(using: quoteValue)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
                    .padding(.bottom, 2)
            }
            value.typography(.paragraph1)
                .foregroundColor(.semantic.text)
        }
        .bindings {
            subscribe($quoteValue, to: blockchain.api.nabu.gateway.price.crypto[value.currency.code].fiat[{ quoteCurrency }].quote.value)
        }
    }
}

public struct MoneyValueQuoteAndChangePercentageView: View {

    @Environment(\.moneyValueViewQuoteCurrency) private var quoteCurrency

    let value: MoneyValue
    let alignment: HorizontalAlignment

    @State private var delta: Double?
    @State private var quoteValue: MoneyValue?

    public init(
        _ value: MoneyValue,
        alignment: HorizontalAlignment = .trailing
    ) {
        self.value = value
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            if let quoteValue {
                value.convert(using: quoteValue)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
            } else {
                Text("$999.99")
                    .typography(.paragraph2)
                    .redacted(reason: .placeholder)
            }
            if let delta {
                MoneyValueDeltaView(delta)
                    .padding(.top, 2)
            } else {
                Text("00.00%")
                    .typography(.caption1)
                    .redacted(reason: .placeholder)
            }
        }
        .bindings {
            subscribe($quoteValue, to: blockchain.api.nabu.gateway.price.crypto[value.currency.code].fiat[{ quoteCurrency }].quote.value)
            subscribe($delta, to: blockchain.api.nabu.gateway.price.crypto[value.currency.code].fiat[{ quoteCurrency }].delta.since.yesterday)
        }
    }
}

public struct MoneyValueCodeNetworkView: View {

    private var currency: CurrencyType

    public init(_ currency: CurrencyType) {
        self.currency = currency
    }

    public var body: some View {
        HStack(spacing: Spacing.padding1) {
            Text(currency.displayCode)
                .typography(.caption1.slashedZero())
                .foregroundColor(.semantic.text)
            if let networkToDisplay {
                TagView(
                    text: networkToDisplay.networkConfig.shortName,
                    variant: .outline
                )
            }
        }
    }

    private var networkToDisplay: EVMNetwork? {
        currency.cryptoCurrency?.network()
    }
}

public struct MoneyValueDeltaView: View {

    private var delta: Double?

    public init(_ delta: Double?) {
        self.delta = delta
    }

    public var body: some View {
        if let deltaChangeText {
            Text(deltaChangeText)
                .typography(.caption1.slashedZero())
                .foregroundColor(color)
        }
    }

    private var deltaDecimal: Decimal? {
        delta.map { Decimal($0) }
    }

    private var color: Color {
        guard let delta = deltaDecimal else {
            return .semantic.body
        }
        if delta.isSignMinus {
            return .semantic.pink
        } else if delta.isZero {
            return .semantic.body
        } else {
            return .semantic.success
        }
    }

    private var deltaChangeText: String? {
        guard let deltaDecimal else {
            return nil
        }

        let arrowString = {
            if deltaDecimal.isZero {
                return ""
            }
            if deltaDecimal.isSignMinus {
                return "↓ "
            }

            return "↑ "
        }()

        return "\(arrowString)\(deltaDecimal.abs().formatted(.percent.precision(.fractionLength(2))))"
    }
}

public struct MoneyValueHeaderView<Subtitle: View>: View {

    @BlockchainApp var app
    @State private var isHidingBalance = false

    let value: MoneyValue
    let subtitle: Subtitle

    public init(
        title value: MoneyValue,
        @ViewBuilder subtitle: () -> Subtitle
    ) {
        self.value = value
        self.subtitle = subtitle()
    }

    public var body: some View {
        VStack(alignment: .center) {
            HStack {
                value.typography(.title1)
                    .foregroundColor(.semantic.title)
                if isHidingBalance {
                    IconButton(icon: .visibilityOff.small().color(.semantic.muted)) {
                        $app.post(value: false, of: blockchain.ux.dashboard.is.hiding.balance)
                    }
                } else {
                    IconButton(icon: .visibilityOn.small().color(.semantic.muted)) {
                        $app.post(value: true, of: blockchain.ux.dashboard.is.hiding.balance)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            subtitle.typography(.paragraph2.slashedZero())
        }
        .bindings {
            subscribe($isHidingBalance, to: blockchain.ux.dashboard.is.hiding.balance)
        }
    }
}

public struct MoneyValueRowView<Byline: View>: View {

    public enum Variant {
        /// Price / Crypto Balance
        case quote
        /// Fiat Balance / Delta
        case delta
        /// Crypto Balance
        case value
    }

    @Environment(\.typography) var typography
    @Environment(\.moneyValueViewQuoteCurrency) private var quoteCurrency

    let value: MoneyValue
    let variant: Variant
    let byline: Byline

    public init(_ value: MoneyValue, variant: Variant = .delta, byline: () -> Byline = EmptyView.init) {
        self.value = value
        self.variant = variant
        self.byline = byline()
    }

    public var body: some View {
        TableRow(
            leading: {
                value.currency.logo(size: 24.pt)
            },
            title: {
                TableRowTitle(value.currency.name)
            },
            byline: { byline },
            trailing: {
                if value.isCrypto {
                    switch variant {
                    case .quote:
                        MoneyValueAndQuoteView(value, alignment: .trailing)
                    case .delta:
                        MoneyValueQuoteAndChangePercentageView(value, alignment: .trailing)
                    case .value:
                        MoneyValueView(value)
                            .typography(.paragraph1)
                            .foregroundColor(.semantic.title)
                    }
                } else {
                    MoneyValueView(value)
                        .typography(.paragraph1)
                        .foregroundColor(.semantic.title)
                }
            }
        )
        .background(Color.semantic.background)
    }
}

extension MoneyValue: View {

    @ViewBuilder
    public var body: some View {
        MoneyValueView(self)
    }

    @ViewBuilder
    public func quoteView(alignment: HorizontalAlignment = .trailing) -> some View {
        MoneyValueAndQuoteView(self, alignment: alignment)
    }

    @ViewBuilder
    public func deltaView(alignment: HorizontalAlignment = .trailing) -> some View {
        MoneyValueQuoteAndChangePercentageView(self, alignment: alignment)
    }

    @ViewBuilder
    public func rowView<Byline: View>(_ type: MoneyValueRowView<Byline>.Variant, @ViewBuilder byline: () -> Byline = EmptyView.init) -> some View {
        MoneyValueRowView(self, variant: type, byline: byline)
    }

    @ViewBuilder
    public func headerView(@ViewBuilder _ subtitle: () -> some View = EmptyView.init) -> some View {
        MoneyValueHeaderView(title: self, subtitle: subtitle)
    }
}

let percentageFormatter: NumberFormatter = with(NumberFormatter()) { formatter in
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 1
}

/// Environment key set by `PrimaryNavigation`
private struct MoneyValueViewQuoteCurrencyEnvironmentKey: EnvironmentKey {
    static var defaultValue: L & I_blockchain_type_currency = blockchain.user.currency.preferred.fiat.display.currency
}

extension EnvironmentValues {

    public var moneyValueViewQuoteCurrency: L & I_blockchain_type_currency {
        get { self[MoneyValueViewQuoteCurrencyEnvironmentKey.self] }
        set { self[MoneyValueViewQuoteCurrencyEnvironmentKey.self] = newValue }
    }
}

struct MoneyView_Previews: PreviewProvider {
    static var bitcoinBalance = MoneyValue
        .create(major: 1.34567, currency: .crypto(.bitcoin))

    static var fiatCurrency: FiatCurrency = .GBP

    static var app = App.preview
        .withPreviewData(fiatCurrency: fiatCurrency.code)
        .setup { app in
            try await app
                .set(blockchain.ux.dashboard.is.hiding.balance, to: true)
        }

    static var previews: some View {
        VStack {
            MoneyValueHeaderView(
                title: .create(major: 98.01, currency: .fiat(fiatCurrency)),
                subtitle: {
                    HStack {
                        MoneyValueView(.create(major: 1.99, currency: .fiat(fiatCurrency)))
                        Text("(34.03%)")
                    }
                    .foregroundColor(.semantic.pink)
                }
            )
            Spacer().frame(maxHeight: 44.pt)
            bitcoinBalance
            MoneyValue.create(major: 1699.86, currency: .fiat(fiatCurrency))
            VStack {
                Title("Quote")
                MoneyValueRowView(bitcoinBalance, variant: .quote)
                    .cornerRadius(8)
                Title("Delta")
                MoneyValueRowView(bitcoinBalance, variant: .delta)
                    .cornerRadius(8)
                Title("Delta One")
                MoneyValueRowView(.one(currency: .bitcoin), variant: .delta)
                    .cornerRadius(8)
                Title("Value")
                MoneyValueRowView(bitcoinBalance, variant: .value)
                    .cornerRadius(8)
                Title("Fiat")
                MoneyValueRowView(.create(major: 120.24, currency: .fiat(fiatCurrency)), variant: .delta)
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic.light.ignoresSafeArea())
        .app(app)
        .previewDisplayName("Dashboard Balances")
    }

    static func Title(_ string: String) -> some View {
        Text(string)
            .typography(.caption1)
            .foregroundColor(.semantic.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
