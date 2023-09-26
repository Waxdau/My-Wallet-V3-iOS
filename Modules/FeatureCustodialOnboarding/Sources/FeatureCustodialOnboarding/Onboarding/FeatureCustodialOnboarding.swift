import BlockchainUI
import FeatureQuickActions
import SwiftUI

public struct CustodialOnboardingDashboardView: View {

    @ObservedObject var onboarding: CustodialOnboardingService

    public init(service: CustodialOnboardingService) {
        self.onboarding = service
    }

    public var body: some View {
        VStack(spacing: 16.pt) {
            MoneyValue.zero(currency: onboarding.currency).headerView()
                .padding(.top)
            if onboarding.isRejected {
                RejectedVerificationView()
            } else {
                QuickActionsView(tag: blockchain.ux.user.custodial.onboarding.dashboard.quick.action)
                    .padding(.vertical)
                CustodialOnboardingProgressView(progress: onboarding.progress)
                CustodialOnboardingTaskListView(service: onboarding)
                if onboarding.isVerified {
                    CustodialOnboardingHelpSectionView()
                }
            }
        }
        .padding(.horizontal)
    }
}

struct CustodialOnboardingProgressView: View {

    let progress: Double

    var body: some View {
        TableRow(
            leading: {
                ProgressView(value: progress, total: 1)
                    .progressViewStyle(
                        BlockchainCircularProgressViewStyle(
                            stroke: .semantic.primary,
                            background: .semantic.light,
                            lineWidth: 10.pmin,
                            indeterminate: false,
                            lineCap: .round
                        )
                    )
                    .inscribed {
                        Text(Rational(approximating: progress).scaled(toDenominator: 3).string)
                            .typography(.paragraph2.slashedZero())
                            .scaledToFit()
                    }
                    .foregroundTexture(.semantic.primary)
                    .frame(maxWidth: 10.vw)
            },
            title: {
                Text(L10n.completeYourProfile)
                    .typography(.caption1)
                    .foregroundColor(.semantic.muted)
            },
            byline: {
                Text(L10n.tradeCryptoToday)
                    .typography(.body2)
                    .foregroundColor(.semantic.title)
            }
        )
        .background(Color.semantic.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CustodialOnboardingTaskListView: View {

    @BlockchainApp var app
    @ObservedObject var service: CustodialOnboardingService

    var body: some View {
        DividedVStack(spacing: 0) {
            CustodialOnboardingTaskRowView(
                icon: .email,
                tint: .semantic.defi,
                title: L10n.verifyYourEmail,
                description: L10n.completeIn30Seconds,
                state: service.state(for: .verifyEmail)
            )
            .onTapGesture {
                $app.post(event: blockchain.ux.user.custodial.onboarding.dashboard.verify.email.paragraph.row.tap)
            }
            CustodialOnboardingTaskRowView(
                icon: .identification,
                tint: .semantic.primary,
                title: L10n.verifyYourIdentity,
                description: L10n.completeIn2Minutes,
                state: service.state(for: .verifyIdentity)
            )
            .onTapGesture {
                $app.post(event: blockchain.ux.user.custodial.onboarding.dashboard.verify.identity.paragraph.row.tap)
            }
            CustodialOnboardingTaskRowView(
                icon: .cart,
                tint: .semantic.success,
                title: L10n.buyCrypto,
                description: L10n.completeIn10Seconds,
                state: service.state(for: .purchaseCrypto)
            )
            .onTapGesture {
                $app.post(event: blockchain.ux.user.custodial.onboarding.dashboard.buy.crypto.paragraph.row.tap)
            }
        }
        .background(Color.semantic.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .batch {
            set(blockchain.ux.user.custodial.onboarding.dashboard.verify.email.paragraph.row.tap.then.emit, to: blockchain.ux.user.custodial.onboarding.dashboard.configuration.verify.email)
            set(blockchain.ux.user.custodial.onboarding.dashboard.verify.identity.paragraph.row.tap.then.emit, to: blockchain.ux.user.custodial.onboarding.dashboard.configuration.verify.identity)
            set(blockchain.ux.user.custodial.onboarding.dashboard.buy.crypto.paragraph.row.tap.then.emit, to: blockchain.ux.user.custodial.onboarding.dashboard.configuration.buy.crypto)
        }
    }
}

struct CustodialOnboardingTaskRowView: View {

    enum ViewState {
        case todo, highlighted, pending, done
    }

    let icon: Icon
    let tint: Color
    let title: String
    let description: String
    let state: ViewState

    var body: some View {
        TableRow(
            leading: {
                icon.small().color(tint)
                    .overlay(Group {
                        if state == .highlighted {
                            Circle()
                                .fill(Color.semantic.pink)
                                .frame(width: 8.pt, height: 8.pt)
                        }
                    }, alignment: .topTrailing)
            },
            title: {
                Text(title)
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)
            },
            byline: {
                Group {
                    switch state {
                    case .done:
                        Text(L10n.completed)
                            .foregroundColor(.semantic.success)
                    case .pending:
                        Text(L10n.inReview)
                            .foregroundColor(.semantic.text)
                    default:
                        Text(description)
                            .foregroundColor(.semantic.text)
                    }
                }
                .typography(.caption1)
            },
            trailing: {
                switch state {
                case .done:
                    Icon.checkCircle.small().color(.semantic.success)
                case .pending:
                    Icon.clockFilled.small().color(.semantic.muted)
                default:
                    Icon.chevronRight.small().color(tint)
                }
            }
        )
        .opacity(state == .todo ? 0.5 : 1)
        .background(Color.semantic.background)
    }
}

struct CustodialOnboardingHelpSectionView: View {

    @BlockchainApp var app

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizationConstants.SuperApp.Dashboard.helpSectionHeader)
                    .typography(.body2)
                    .foregroundColor(.semantic.body)
                Spacer()
            }
            .padding(.vertical, Spacing.padding1)
            VStack(spacing: 0) {
                PrimaryRow(
                    title: LocalizationConstants.SuperApp.Help.supportCenter,
                    textStyle: .superApp,
                    trailing: { trailingView },
                    action: {
                        app.post(event: blockchain.ux.customer.support.show.help.center)
                    }
                )
            }
            .cornerRadius(16, corners: .allCorners)
        }
    }

    @ViewBuilder var trailingView: some View {
        Icon.chevronRight
            .color(Color.semantic.title)
            .frame(height: 18)
            .flipsForRightToLeftLayoutDirection(true)
    }
}

let preview_quick_actions: Any = [
    [
        "id": "buy",
        "title": "Buy",
        "icon": "https://login.blockchain.com/static/asset/icon/plus.svg",
        "select": [
            "then": [
                "emit": "blockchain.ux.frequent.action.brokerage.buy"
            ]
        ]
    ],
    [
        "id": "deposit",
        "title": "Deposit",
        "icon": "https://login.blockchain.com/static/asset/icon/receive.svg",
        "select": [
            "then": [
                "emit": "blockchain.ux.kyc.launch.verification"
            ]
        ]
    ]
]

struct CustodialOnboardingDashboardView_Previews: PreviewProvider {

    static var previews: some View {
        let app = App.preview { app in
            try await app.set(blockchain.ux.user.custodial.onboarding.dashboard.quick.action.list.configuration, to: preview_quick_actions)
            try await app.set(blockchain.user.email.is.verified, to: false)
            try await app.set(blockchain.user.is.verified, to: false)
        }
        let (onVerifyEmail, onVerifyIdentity) = (
            app.on(blockchain.ux.user.custodial.onboarding.dashboard.configuration.verify.email) { _ async throws in
                try await app.set(blockchain.user.email.is.verified, to: !app.get(blockchain.user.email.is.verified))
            }.subscribe(),
            app.on(blockchain.ux.user.custodial.onboarding.dashboard.configuration.verify.identity) { _ async throws in
                try await app.set(blockchain.user.is.verified, to: !app.get(blockchain.user.is.verified))
            }.subscribe()
        )
        let service = CustodialOnboardingService()
        withDependencies { dependencies in
            dependencies.app = app
        } operation: {
            VStack {
                CustodialOnboardingDashboardView(service: service)
                Spacer()
            }
            .padding()
            .background(Color.semantic.light.ignoresSafeArea())
            .app(app)
            .onAppear {
                withExtendedLifetime((onVerifyEmail, onVerifyIdentity)) {
                    service
                }.request()
            }
        }
        .previewDisplayName("Dashboard")
    }
}

struct CustodialOnboardingProgressView_Previews: PreviewProvider {

    static var previews: some View {
        let app = App.preview
        withDependencies { dependencies in
            dependencies.app = app
        } operation: {
            VStack {
                Spacer()
                CustodialOnboardingProgressView(progress: 0 / 3).padding(.horizontal)
                CustodialOnboardingProgressView(progress: 1 / 3).padding(.horizontal)
                CustodialOnboardingProgressView(progress: 2 / 3).padding(.horizontal)
                Spacer()
            }
            .background(Color.semantic.light.ignoresSafeArea())
            .app(app)
        }
        .previewDisplayName("Profile Progress")
    }
}
