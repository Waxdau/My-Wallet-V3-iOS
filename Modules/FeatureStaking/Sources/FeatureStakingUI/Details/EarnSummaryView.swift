// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import BlockchainUI
import DIKit
import FeatureStakingDomain
import SwiftUI

@MainActor
public struct EarnSummaryView: View {

    struct SheetModel {
        let title: String
        let description: String
    }

    let id = blockchain.ux.earn.portfolio.product.asset.summary

    var product: EarnProduct { try! context[blockchain.user.earn.product.id].decode() }
    var currency: CryptoCurrency { try! context[blockchain.user.earn.product.asset.id].decode() }

    @BlockchainApp var app
    @Environment(\.context) var context
    @State var sheetModel: SheetModel?

    @StateObject var object = Object()

    public init() {}

    public var body: some View {
        main
            .superAppNavigationBar(
                title: {
                    navigationTitleView(
                        title: L10n.summaryTitle.interpolating(currency.code, product.title),
                        iconUrl: currency.logoURL
                    )
                },
                trailing: { dismiss() },
                scrollOffset: nil
            )
            .navigationBarHidden(true)
            .bottomSheet(item: $sheetModel) { model in
                sheet(model: model)
            }
    }

    var main: some View {
        VStack {
            if let model = object.model {
                Loaded(
                    json: model,
                    bondingTxsRequests: object.pendingBondingRequests,
                    sheetModel: $sheetModel
                ).id(model)
            } else {
                BlockchainProgressView()
            }
        }
        .onAppear { object.start(on: app, in: context) }
    }

    @MainActor @ViewBuilder
    func navigationTitleView(title: String?, iconUrl: URL?) -> some View {
        HStack(spacing: Spacing.padding1) {
            if let url = iconUrl {
                AsyncMedia(
                    url: url,
                    content: { media in
                        media.cornerRadius(12)
                    },
                    placeholder: {
                        Color.semantic.muted
                            .opacity(0.3)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(.circular)
                            )
                            .clipShape(Circle())
                    }
                )
                .resizingMode(.aspectFit)
                .frame(width: 24.pt, height: 24.pt)
            }

            Text(title ?? "")
                .typography(.body2)
                .foregroundColor(.WalletSemantic.title)
        }
    }

    @MainActor @ViewBuilder
    func dismiss() -> some View {
        IconButton(icon: .navigationCloseButton()) {
            $app.post(event: id.article.plain.navigation.bar.button.close.tap)
        }
        .frame(width: 24.pt)
    }

    @ViewBuilder func sheet(model: SheetModel) -> some View {
        VStack(spacing: Spacing.padding3) {
            HStack {
                Text(model.title)
                    .typography(.body2)
                Spacer()
                IconButton(icon: .navigationCloseButton()) {
                    sheetModel = nil
                }
            }
            HStack(spacing: .zero) {
                Text(model.description)
                    .multilineTextAlignment(.leading)
                    .typography(.body1)
                Spacer()
            }
            PrimaryButton(title: L10n.gotIt) {
                sheetModel = nil
            }
        }
        .padding(.horizontal, Spacing.padding3)
    }
}

extension EarnSummaryView {

    struct Loaded: View {

        let id = blockchain.ux.earn.portfolio.product.asset.summary

        @BlockchainApp var app
        @Binding var sheetModel: SheetModel?
        @Environment(\.context) var context

        let my: L_blockchain_user_earn_product_asset.JSON
        var bondingTxsRequests: [EarnBondingUnbondingRequests] = []

        var dayFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day]
            formatter.unitsStyle = .short
            return formatter
        }()

        var product: EarnProduct { try! context[blockchain.user.earn.product.id].decode() }
        var currency: CryptoCurrency { try! context[blockchain.user.earn.product.asset.id].decode() }

        init(
            json: L_blockchain_user_earn_product_asset.JSON,
            bondingTxsRequests: [EarnBondingUnbondingRequests],
            sheetModel: Binding<SheetModel?>
        ) {
            self.my = json
            self.bondingTxsRequests = bondingTxsRequests
            _sheetModel = sheetModel
        }

        @State var exchangeRate: MoneyValue?
        @State var tradingBalance: MoneyValue?
        @State var pkwBalance: MoneyValue?
        @State var earningBalance: MoneyValue?
        @State var isWithdrawDisabled: Bool = false
        @State var learnMore: URL?
        @State var countDownLock: Bool = false

        var body: some View {
            VStack(spacing: .zero) {
                Do {
                    try balance(value: my.account.balance(MoneyValue.self))
                } catch: { _ in
                    EmptyView()
                }
                content
                buttons
            }
            .background(Color.semantic.light.ignoresSafeArea())
            .bindings {
                subscribe($exchangeRate, to: blockchain.api.nabu.gateway.price.crypto[currency.code].fiat.quote.value)
                subscribe($learnMore, to: blockchain.ux.earn.portfolio.product.asset.summary.learn.more.url)
                subscribe($tradingBalance, to: blockchain.user.trading.account[currency.code].balance.available)
                subscribe($pkwBalance, to: blockchain.user.pkw.asset[currency.code].balance)
                subscribe($earningBalance, to: blockchain.user.earn.product[product.value].asset[currency.code].account.earning)
            }
            .batch {
                set(id.add.paragraph.button.primary.tap, to: action)
                set(id.withdraw.paragraph.button.small.secondary.tap.then.emit, to: $app[product.withdraw(currency)])
                set(id.learn.more.paragraph.button.small.secondary.tap.then.launch.url, to: learnMore)
                set(id.article.plain.navigation.bar.button.close.tap.then.close, to: true)
            }
            .batch {
                set(id.view.activity.paragraph.row.tap.then.enter.into, to: blockchain.ux.user.activity.all)
            }
        }

        @ViewBuilder var buttons: some View {
            VStack(spacing: Spacing.padding1) {
                if product == .staking, let countdownDate = bondingTxsRequests.withdrawalLockDate {
                    CountDownView(
                        secondsRemaining: countdownDate.timeIntervalSinceNow,
                        onComplete: {
                            countDownLock = false
                        }
                    )
                    .padding(.top, Spacing.padding2)
                    .onAppear {
                        countDownLock = true
                    }
                } else {
                    Rectangle().foregroundColor(.clear).frame(height: Spacing.padding3)
                }
                ZStack {
                    HStack(spacing: Spacing.padding1) {
                        SecondaryButton(
                            title: L10n.withdraw,
                            leadingView: { Icon.walletSend.frame(width: 10, height: 14) },
                            action: {
                                $app.post(event: id.withdraw.paragraph.button.small.secondary.tap)
                            }
                        )
                        .disabled(
                            my.limit.withdraw.is.disabled ?? false
                            || countDownLock
                            || (product == .active && bondingTxsRequests.withdrawalLockDate.isNotNil)
                            || (product == .active && earningBalance?.isZero ?? false)
                        )
                        SecondaryButton(
                            title: L10n.add,
                            leadingView: { Icon.walletReceive.frame(width: 10, height: 14) },
                            action: {
                                $app.post(
                                    event: id.add.paragraph.button.primary.tap,
                                    context: [
                                        blockchain.ui.type.action.then.enter.into.detents: [
                                            blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                                        ]
                                    ]
                                )
                            }
                        )
                        .disabled(!(my.is.eligible ?? false))
                    }
                    .padding([.leading, .trailing], Spacing.padding3)
                    .padding(.bottom, Spacing.padding2)
                }
            }
            .background(
                BottomSheetBackgroundShape()
                    .foregroundColor(.semantic.background)
                    .ignoresSafeArea()
            )
        }

        var action: L_blockchain_ui_type_action.JSON {
            var action = L_blockchain_ui_type_action.JSON(.empty)
            let isTradingNotZeroOrDust = tradingBalance.isNotZeroOrDust(using: exchangeRate) ?? false
            let isPkwNotZeroOrDust = pkwBalance.isNotZeroOrDust(using: exchangeRate) ?? false
            if isTradingNotZeroOrDust || isPkwNotZeroOrDust {
                action.then.emit = product.deposit(currency)
            } else {
                action.then.enter.into = my.is.eligible == true
                    ? blockchain.ux.earn.discover.product.asset.no.balance[].ref(to: context)
                    : blockchain.ux.earn.discover.product.not.eligible[].ref(to: context)
                action.policy.discard.if = isTradingNotZeroOrDust || isPkwNotZeroOrDust
            }
            return action
        }

        @ViewBuilder func balance(value: MoneyValue) -> some View {
            VStack(spacing: Spacing.padding1) {
                Do {
                    try Text(value.convert(using: exchangeRate.or(throw: "No exchange rate")).displayString)
                        .typography(.title1)
                } catch: { _ in
                    EmptyView()
                }
                Text(value.displayString).typography(.body2).foregroundColor(.semantic.text)
            }
            .padding(.top, Spacing.padding4)
            .padding(.bottom, Spacing.padding1)
        }

        @ViewBuilder func rowQuoted(
            title: String,
            value: MoneyValue?,
            info: SheetModel? = nil
        ) -> some View {
            if let value {
                if let info {
                    TableRow(
                        title: {
                            HStack {
                                TableRowTitle(title)
                                IconButton(
                                    icon: .information.micro(),
                                    action: {
                                        sheetModel = info
                                    }
                                )
                            }
                        },
                        trailing: {
                            VStack(alignment: .trailing, spacing: 6) {
                                TableRowTitle(value.quotedDisplayString(using: exchangeRate))
                                TableRowByline(value.displayString)
                            }
                        }
                    )
                    .frame(minHeight: 80.pt)
                    .backport
                    .listDivider()
                } else {
                    TableRow(
                        title: TableRowTitle(title),
                        trailing: {
                            VStack(alignment: .trailing, spacing: 6) {
                                TableRowTitle(value.quotedDisplayString(using: exchangeRate))
                                TableRowByline(value.displayString)
                            }
                        }
                    )
                    .frame(minHeight: 80.pt)
                    .backport
                    .listDivider()
                }
            } else {
                EmptyView()
            }
        }

        @ViewBuilder func row(
            title: String,
            trailingTitle: String,
            info: SheetModel? = nil
        ) -> some View {
            if let info {
                TableRow(
                    title: {
                        HStack {
                            TableRowTitle(title)
                            IconButton(
                                icon: .information.micro(),
                                action: {
                                    sheetModel = info
                                }
                            )
                        }
                    },
                    trailing: { TableRowTitle(trailingTitle) }
                )
                .frame(minHeight: 80.pt)
                .backport
                .listDivider()
            } else {
                TableRow(
                    title: TableRowTitle(title),
                    trailingTitle: TableRowTitle(trailingTitle)
                )
                .frame(minHeight: 80.pt)
                .backport
                .listDivider()
            }
        }

        @ViewBuilder var content: some View {
            List {
                Section {
                    if product == .active, let quote = exchangeRate?.displayString {
                        row(
                            title: L10n.price.interpolating(currency.displayCode),
                            trailingTitle: quote
                        )
                    }
                    rowQuoted(
                        title: product == .active ? L10n.netEarnings : L10n.totalEarned,
                        value: try? my.account.total.rewards(MoneyValue.self),
                        info: product.totalEarnedSheetModel
                    )
                    if product == .active {
                        rowQuoted(
                            title: product.totalTitle,
                            value: try? my.account.balance(MoneyValue.self)
                            - my.account.pending.deposit(MoneyValue.self)
                            - my.account.pending.withdrawal(MoneyValue.self)
                            - my.account.bonding.deposits(MoneyValue.self)
                        )
                        if let bonding = try? my.account.bonding.deposits(MoneyValue.self), bonding.isPositive {
                            rowQuoted(
                                title: product == .staking ? L10n.bonding : L10n.onHold,
                                value: bonding,
                                info: product.onHoldSheetModel
                            )
                        }
                    } else if product == .staking {
                        if let rate = my.rates.rate {
                            row(
                                title: L10n.currentRate,
                                trailingTitle: percentageFormatter.string(from: NSNumber(value: rate)) ?? "0%",
                                info: product.rateSheetModel
                            )
                        }
                        row(
                            title: L10n.paymentFrequency,
                            trailingTitle: frequencyTitle(my.limit.reward.frequency),
                            info: product.frequencySheetModel
                        )
                    } else if product == .savings, let accrued = try? my.account.pending.interest(MoneyValue.self) {
                        rowQuoted(
                            title: L10n.accruedThisMonth,
                            value: accrued,
                            info: product.monthlyEarningsSheetModel
                        )
                    }
                }
                .background(Color.semantic.background)
                .listRowInsets(.zero)
                if product != .staking {
                    Section {
                        if let rate = my.rates.rate {
                            row(
                                title: product == .active ? L10n.estimatedAnnualRate : L10n.currentRate,
                                trailingTitle: percentageFormatter.string(from: NSNumber(value: rate)) ?? "0%",
                                info: product.rateSheetModel
                            )
                            .listRowSeparatorTint(Color.semantic.light)
                        }

                        if let trigger = try? my.rates.trigger.price(MoneyValue.self).displayString {
                            row(
                                title: L10n.triggerPrice,
                                trailingTitle: trigger,
                                info: product.triggerSheetModel
                            )
                            .listRowSeparatorTint(Color.semantic.light)
                        }

                        row(
                            title: L10n.paymentFrequency,
                            trailingTitle: frequencyTitle(my.limit.reward.frequency),
                            info: product.frequencySheetModel
                        )
                        .listRowSeparatorTint(Color.semantic.light)

                        if let nextPayment = product.nextPaymentDate {
                            row(
                                title: L10n.nextPayment,
                                trailingTitle: nextPayment
                            )
                            .listRowSeparatorTint(Color.semantic.light)
                        }

                        if let initialHoldPeriod = try? my.limit.lock.up.duration(Int.self),
                           initialHoldPeriod > 0,
                           let numberOfDays = dayFormatter.string(from: TimeInterval(initialHoldPeriod))
                        {
                            row(
                                title: L10n.initialHoldPeriod,
                                trailingTitle: numberOfDays,
                                info: product.initialHoldPeriodSheetModel
                            )
                            .listRowSeparatorTint(Color.semantic.light)
                        }
                    }
                    .background(Color.semantic.background)
                    .listRowInsets(.zero)
                }
                footer
            }
            .tableRowBackground(Color.semantic.background)
            .hideScrollContentBackground()
            .listStyle(.insetGrouped)
            .listRowInsets(.zero)
            .background(Color.semantic.light)
        }

        func frequencyTitle(_ frequency: Tag?) -> String {
            let frequency = frequency ?? blockchain.user.earn.product.asset.limit.reward.frequency.monthly[]
            switch frequency {
            case blockchain.user.earn.product.asset.limit.reward.frequency.daily:
                return L10n.daily
            case blockchain.user.earn.product.asset.limit.reward.frequency.weekly:
                return L10n.weekly
            case blockchain.user.earn.product.asset.limit.reward.frequency.monthly:
                return L10n.monthly
            default:
                return ""
            }
        }

        @ViewBuilder var pendingRequestsSection: some View {
            Section(
                header: SectionHeader(title: L10n.PendingWithdrawal.sectionTitle, variant: .superappLight)
            ) {
                if product == .active {
                    TableRow(
                        leading: { Icon.walletSend.circle().small().color(.semantic.title) },
                        title: TableRowTitle(L10n.PendingWithdrawal.activeTitle.interpolating(currency.displayCode)),
                        byline: TableRowByline(L10n.PendingWithdrawal.subtitle).foregroundColor(.semantic.primaryMuted),
                        trailing: { TableRowByline(L10n.PendingWithdrawal.date).foregroundColor(.semantic.muted) }
                    )
                } else if product == .staking {
                    ForEach(bondingTxsRequests, id: \.self) { request in
                        if request.type == .bonding {
                            pendingBondingRow(request)
                                .frame(minHeight: 80.pt)
                                .backport
                                .listDivider()
                        } else {
                            pendingUnbondingRow(request)
                                .frame(minHeight: 80.pt)
                                .backport
                                .listDivider()
                        }
                    }
                }
            }
            .background(Color.semantic.background)
            .textCase(nil)
            .listRowInsets(.zero)
        }

        @ViewBuilder func pendingBondingRow(_ request: EarnBondingUnbondingRequests) -> some View {
            TableRow(
                leading: { Icon.walletReceive.circle().small().color(.semantic.title) },
                title: TableRowTitle(L10n.PendingWithdrawal.staked.interpolating(request.currency)),
                byline: {
                    TableRowByline(L10n.PendingWithdrawal.bondingPeriod.interpolating("\(request.daysLeft)"))
                        .typography(.caption1)
                },
                trailing: {
                    VStack(alignment: .trailing, spacing: 6) {
                        if let expiry = request.expiryDate {
                            TableRowTitle(DateFormatter.medium.string(from: expiry))
                        }
                        if let amount = request.amount {
                            TableRowByline(amount.displayString)
                                .typography(.caption1)
                        }
                    }
                }
            )
        }

        @ViewBuilder func pendingUnbondingRow(_ request: EarnBondingUnbondingRequests) -> some View {
            TableRow(
                leading: { Icon.walletSend.circle().small().color(.semantic.title) },
                title: TableRowTitle(L10n.PendingWithdrawal.title.interpolating(request.currency)),
                byline: {
                    TableRowByline(L10n.PendingWithdrawal.unbondingPeriod.interpolating("\(request.daysLeft)"))
                        .typography(.caption1)
                },
                trailing: {
                    VStack(alignment: .trailing, spacing: 6) {
                        if let expiry = request.expiryDate {
                            TableRowTitle(DateFormatter.medium.string(from: expiry))
                        }
                        if let amount = request.amount {
                            TableRowByline("-\(amount.displayString)")
                                .typography(.caption1)
                        }
                    }
                }
            )
        }

        @ViewBuilder var footer: some View {
            Group {
                if product == .active, bondingTxsRequests.withdrawalLockDate.isNotNil {
                    pendingRequestsSection
                } else if product == .staking, !bondingTxsRequests.isEmpty {
                    pendingRequestsSection
                } else if let isDisabled = my.limit.withdraw.is.disabled, isDisabled, let disclaimer = product.withdrawDisclaimer {
                    Section {
                        AlertCard(
                            title: L10n.important,
                            message: disclaimer,
                            variant: .warning,
                            backgroundColor: .semantic.background
                        ) {
                            SmallSecondaryButton(title: L10n.learnMore) {
                                app.post(event: id.learn.more.paragraph.button.small.secondary.tap[].ref(to: context), context: context)
                            }
                        }
                    }
                    .listRowInsets(.zero)
                }
                if product == .active {
                    Section {
                        AlertCard(
                            title: L10n.important,
                            message: L10n.activeWithdrawDisclaimer,
                            variant: .warning,
                            backgroundColor: .semantic.background
                        ) {
                            SmallSecondaryButton(title: L10n.learnMore) {
                                app.post(event: id.learn.more.paragraph.button.small.secondary.tap[].ref(to: context), context: context)
                            }
                        }
                    }
                    .listRowInsets(.zero)
                } else if product == .staking, let unbonding = my.limit.days.unbonding {
                    Section {
                        AlertCard(
                            title: L10n.Unstaking.title,
                            message: L10n.Unstaking.message.interpolating(String(unbonding)),
                            variant: .default,
                            backgroundColor: .semantic.background
                        ) {
                            SmallSecondaryButton(title: L10n.learnMore) {
                                app.post(event: id.learn.more.paragraph.button.small.secondary.tap[].ref(to: context), context: context)
                            }
                        }
                    }
                    .listRowInsets(.zero)
                }
            }
            .background(Color.semantic.background)
        }
    }
}

extension EarnSummaryView {

    @MainActor
    class Object: ObservableObject {

        @Published var model: L_blockchain_user_earn_product_asset.JSON?
        @Published var pendingBondingRequests: [EarnBondingUnbondingRequests] = []

        private var cancellables: Set<AnyCancellable> = []

        @MainActor
        func start(on app: AppProtocol, in context: Tag.Context) {

            let product: EarnProduct = try! context[blockchain.user.earn.product.id].decode()
            let currency: CryptoCurrency = try! context[blockchain.user.earn.product.asset.id].decode()
            let service: EarnAccountService = DIKit.resolve(tag: product)

            app.publisher(for: blockchain.user.earn.product.asset[].ref(to: context, in: app), as: L_blockchain_user_earn_product_asset.JSON.self)
                .compactMap(\.value)
                .receive(on: DispatchQueue.main)
                .assign(to: &$model)

            app.on(
                blockchain.ux.transaction.event.execution.status.completed,
                blockchain.ux.transaction.event.execution.status.pending
            )
            .mapToVoid()
            .prepend(())
            .flatMap { _ in
                service.bondingTxs(currency: currency)
                    .ignoreFailure()
            }
            .map { requests -> [EarnBondingUnbondingRequests] in
                let bonding = requests.bondingDeposits.map(EarnBondingUnbondingRequests.init(bonding:))
                let unbonding = requests.unbondingWithdrawals.map(EarnBondingUnbondingRequests.init(unbonding:))
                return (bonding + unbonding).sorted(
                    by: { lhs, rhs -> Bool in
                        guard let left = lhs.expiryDate, let right = rhs.expiryDate else { return false }
                        return left < right
                    }
                )
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingBondingRequests)
        }
    }
}

struct EarnSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        EarnSummaryView()
            .context(
                [
                    blockchain.ux.earn.portfolio.product.id: "staking",
                    blockchain.ux.earn.portfolio.product.asset.id: "ETH",
                    blockchain.user.earn.product.id: "staking",
                    blockchain.user.earn.product.asset.id: "ETH"
                ]
            )
            .app(App.preview)
            .previewDisplayName("Loading")
        EarnSummaryView.Loaded(
            json: preview,
            bondingTxsRequests: [],
            sheetModel: .constant(nil)
        )
            .context(
                [
                    blockchain.ux.earn.portfolio.product.id: "staking",
                    blockchain.ux.earn.portfolio.product.asset.id: "ETH",
                    blockchain.user.earn.product.id: "staking",
                    blockchain.user.earn.product.asset.id: "ETH"
                ]
        )
        .app(App.preview)
        .previewDisplayName("Loaded")
    }

    static let preview: L_blockchain_user_earn_product_asset.JSON = {
        var preview = L_blockchain_user_earn_product_asset.JSON(.empty)
        preview.rates.rate = 0.055
        preview.account.balance[] = MoneyValue.create(minor: "500000000000000000", currency: .crypto(.ethereum))
        preview.account.bonding.deposits[] = MoneyValue.create(minor: "20000000000000000", currency: .crypto(.ethereum))
        preview.account.locked[] = MoneyValue.create(minor: "0", currency: .crypto(.ethereum))
        preview.account.total.rewards[] = MoneyValue.create(minor: "10000000000000000", currency: .crypto(.ethereum))
        preview.account.unbonding.withdrawals[] = MoneyValue.create(minor: "0", currency: .crypto(.ethereum))
        preview.limit.days.bonding = 5
        preview.limit.days.unbonding = 0
        preview.limit.withdraw.is.disabled = true
        preview.limit.reward.frequency = blockchain.user.earn.product.asset.limit.reward.frequency.daily[]
        return preview
    }()
}

extension MoneyValue {
    fileprivate func quotedDisplayString(using rate: MoneyValue?) -> String {
        guard let rate else {
            return displayString
        }

        return convert(using: rate).displayString
    }
}

extension Optional<MoneyValue> {
    func isNotZeroOrDust(using exchangeRate: MoneyValue?) -> Bool? {
        guard let tradingBalance = self, let exchangeRate else { return nil }
        let quote = tradingBalance.convert(using: exchangeRate)
        return !(tradingBalance.isZero || quote.isDust)
    }
}

extension Collection<EarnBondingUnbondingRequests> {
    var withdrawalLockDate: Date? {
        filter { $0.type == .unbonding }
            .compactMap { $0.startDate?.addingTimeInterval(5 * 60) }
            .first(where: { $0 > Date() })
    }
}
