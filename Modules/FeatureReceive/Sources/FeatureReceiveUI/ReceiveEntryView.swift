import BlockchainComponentLibrary
import BlockchainNamespace
import BlockchainUI
import DIKit
import Extensions
import FeatureReceiveDomain
import FeatureTransactionDomain
import MoneyKit
import PlatformKit
import SwiftUI

struct AccountInfo: Identifiable, Hashable, Equatable {
    var id: AnyHashable {
        identifier
    }

    let identifier: String
    let name: String
    let currency: CryptoCurrency
    let network: EVMNetwork?
}

@MainActor
public struct ReceiveEntryView: View {

    typealias L10n = LocalizationConstants.ReceiveScreen.ReceiveEntry

    @BlockchainApp var app

    @State private var search: String = ""
    @State private var isSearching: Bool = false

    @StateObject private var model = Model()

    @State private var mode: AppMode?
    @State private var tradingCurrency: CurrencyType?
    @State private var isCashEnabled: Bool = false

    private let fuzzyAlgorithm = FuzzyAlgorithm(caseInsensitive: true)

    var filtered: [AccountInfo] {
        model.accounts.filter { account in
            search.isEmpty
                || account.name.distance(between: search, using: fuzzyAlgorithm) < 0.2
                || account.currency.name.distance(between: search, using: fuzzyAlgorithm) < 0.2
                || account.currency.code.distance(between: search, using: fuzzyAlgorithm) < 0.2
                || account.network?.networkConfig.shortName.distance(between: search, using: fuzzyAlgorithm) == 0.0
        }
    }

    public init() {}

    public var body: some View {
        content
            .superAppNavigationBar(
                title: {
                    Text(showCashDeposit ? L10n.deposit : L10n.receive)
                        .typography(.body2)
                        .foregroundColor(.semantic.title)
                },
                trailing: { close() },
                scrollOffset: nil
            )
            .navigationBarHidden(true)
            .onAppear {
                model.prepare(app: app)
            }
            .bindings {
                subscribe($mode, to: blockchain.app.mode)
                subscribe($tradingCurrency, to: blockchain.user.currency.preferred.fiat.trading.currency)
                subscribe($isCashEnabled, to: blockchain.ux.user.experiment.dashboard.deposit)
            }
    }

    func close() -> some View {
        IconButton(
            icon: .navigationCloseButton(),
            action: { $app.post(event: blockchain.ux.currency.receive.select.asset.article.plain.navigation.bar.button.close.tap) }
        )
        .batch {
            set(blockchain.ux.currency.receive.select.asset.article.plain.navigation.bar.button.close.tap.then.close, to: true)
        }
    }

    var content: some View {
        VStack {
            if model.accounts.isNotEmpty {
                SearchBar(
                    text: $search,
                    isFirstResponder: $isSearching.animation(),
                    hasAutocorrection: false,
                    cancelButtonText: L10n.cancel,
                    placeholder: L10n.search
                )
                .padding(.top, Spacing.padding2)
                .padding(.horizontal)
                list
            } else {
                Spacer()
                BlockchainProgressView()
                    .transition(.opacity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.semantic.light.ignoresSafeArea())
    }

    var showCashDeposit: Bool {
        isCashEnabled && mode == .trading
    }

    @ViewBuilder var list: some View {
        List {
            if filtered.isEmpty {
                noResultsView
            } else {
                if showCashDeposit, let tradingCurrency, isSearching == false {
                    Section(
                        content: {
                            cashRowView(currency: tradingCurrency)
                        },
                        header: {
                            sectionHeader(title: L10n.cash)
                        }
                    )
                    .listRowInsets(.zero)
                }
                Section(
                    content: {
                        ForEach(filtered) { account in
                            ReceiveEntryRow(id: blockchain.ux.currency.receive.address.asset, account: account)
                                .listRowSeparatorTint(Color.semantic.light)
                                .context(
                                    [
                                        blockchain.coin.core.account.id: account.identifier,
                                        blockchain.ux.currency.receive.address.asset.section.list.item.id: account.identifier
                                    ]
                                )
                        }
                    },
                    header: {
                        if showCashDeposit {
                            sectionHeader(title: L10n.crypto)
                        }
                    }
                )
                .listRowInsets(.zero)
            }
        }
        .padding(.top, Spacing.padding1)
        .hideScrollContentBackground()
        .listStyle(.insetGrouped)
        .background(Color.semantic.light.ignoresSafeArea())
    }

    @ViewBuilder
    func sectionHeader(title: String) -> some View {
        Text(title)
            .typography(.body2)
            .textCase(nil)
            .foregroundColor(.semantic.text)
            .padding(.top, 2.pt)
            .padding(.bottom, Spacing.padding1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cashRowView(currency: CurrencyType) -> some View {
        TableRow(
            leading: { currency.logo() },
            title: {
                Text(currency.name)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
            },
            trailing: {
                Icon.chevronRight
                    .micro()
                    .iconColor(.semantic.text)
            }
        )
        .background(Color.semantic.background)
        .onTapGesture {
            $app.post(
                event: blockchain.ux.currency.receive.select.asset.cash.paragraph.row.tap,
                context: [blockchain.ux.transaction.source.target.id: currency.code]
            )
        }
        .batch {
            set(blockchain.ux.currency.receive.select.asset.cash.paragraph.row.tap.then.emit, to: blockchain.ux.frequent.action.deposit)
        }
    }

    private var noResultsView: some View {
        HStack(alignment: .center, content: {
            Text(L10n.noResults)
                .typography(.body1)
                .foregroundColor(.semantic.title)
                .padding(.vertical, Spacing.padding2)
        })
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
}

extension ReceiveEntryView {
    class Model: ObservableObject {

        private let accountProvider: ReceiveAccountProviding
        private let enabledCurrenciesService: EnabledCurrenciesServiceAPI

        @Published var accounts: [AccountInfo] = []

        init(
            accountProvider: @escaping ReceiveAccountProviding = ReceiveAccountProvider().accounts,
            enabledCurrenciesService: EnabledCurrenciesServiceAPI = resolve()
        ) {
            self.accountProvider = accountProvider
            self.enabledCurrenciesService = enabledCurrenciesService
        }

        func prepare(app: AppProtocol) {
            app.modePublisher()
                .flatMapLatest { [accountProvider, enabledCurrenciesService] appMode -> AnyPublisher<[AccountInfo], Never> in
                    accountProvider(appMode)
                        .ignoreFailure(redirectsErrorTo: app)
                        .map { (accounts: [BlockchainAccount]) in
                            accounts.compactMap { account -> AccountInfo? in
                                guard let crypto = account.currencyType.cryptoCurrency else { return nil }
                                return AccountInfo(
                                    identifier: account.identifier,
                                    name: account.label,
                                    currency: crypto,
                                    network: enabledCurrenciesService.network(for: crypto)
                                )
                            }
                        }
                        .eraseToAnyPublisher()
                }
                .assign(to: &$accounts)
        }
    }
}

struct ReceiveEntryRow: View {

    @BlockchainApp var app

    let id: L & I_blockchain_ui_type_task
    let account: AccountInfo

    var body: some View {
        if #available(iOS 16.0, *) {
            content.alignmentGuide(.listRowSeparatorLeading) { d in d[.leading] }
        } else {
            content
        }
    }

    var content: some View {
        TableRow(
            leading: {
                account.currency.logo()
            },
            title: {
                Text(account.currency.name)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
            },
            byline: {
                HStack(spacing: Spacing.textSpacing) {
                    Text(app.currentMode == .pkw ? account.name : account.currency.displayCode.uppercased())
                        .typography(.caption1)
                        .foregroundColor(.semantic.text)
                    if let network = account.network?.networkConfig.shortName, network.isNotEmpty {
                        TagView(text: network, variant: .outline)
                    }
                }
            },
            trailing: {
                Icon.chevronRight
                    .micro()
                    .iconColor(.semantic.text)
            }
        )
        .background(Color.semantic.background)
        .onTapGesture {
            $app.post(
                event: id.paragraph.row.tap,
                context: [
                    blockchain.ux.asset.id: account.currency.code,
                    blockchain.ux.asset.account.id: account.identifier,
                    blockchain.ui.type.action.then.enter.into.embed.in.navigation: false
                ]
            )
        }
        .batch {
            set(id.paragraph.row.tap.then.enter.into, to: blockchain.ux.currency.receive.address)
        }
    }
}
