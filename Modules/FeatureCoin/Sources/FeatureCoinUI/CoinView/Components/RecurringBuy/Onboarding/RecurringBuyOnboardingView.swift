// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import FeatureCoinDomain
import Localization
import SwiftUI

enum RecurringBuyOnboardingScreens: Hashable, Identifiable, CaseIterable {
    case intro
    case strategy
    case marketUp
    case marketDown
    case final

    private typealias L10n = LocalizationConstants.RecurringBuy

    var id: Self { self }

    var pageIndex: Int {
        switch self {
        case .intro: 0
        case .strategy: 1
        case .marketUp: 2
        case .marketDown: 3
        case .final: 4
        }
    }

    func lottiePageConfig() -> LottiePlayConfig {
        guard self != .intro else {
            return .pauseAtPosition(0.25)
        }
        let index = Double(pageIndex)
        let step = 1.0 / Double(RecurringBuyOnboardingScreens.allCases.count)
        let from = min(max(index * step, 0.0), 1.0)
        let to = min(max((index * step) + step, 0.0), 1.0)
        return .playProgress(from: from, to: to)
    }

    var titles: (main: String, highlighted: String) {
        switch self {
        case .intro:
            (L10n.Onboarding.Pages.first, L10n.Onboarding.Pages.firstHighlight)
        case .strategy:
            (L10n.Onboarding.Pages.second, L10n.Onboarding.Pages.secondHighlight)
        case .marketUp:
            (L10n.Onboarding.Pages.third, L10n.Onboarding.Pages.thirdHighlight)
        case .marketDown:
            (L10n.Onboarding.Pages.fourth, L10n.Onboarding.Pages.fourthHighlight)
        case .final:
            (L10n.Onboarding.Pages.fifth, L10n.Onboarding.Pages.fifthHighlight)
        }
    }

    var footnote: String? {
        guard self == .final else {
            return nil
        }
        return L10n.Onboarding.Pages.fifthFootnote
    }

    var learnMoreLink: String? {
        guard self == .final else {
            return nil
        }
        return "https://support.blockchain.com/hc/en-us/articles/4517680403220"
    }
}

public struct RecurringBuyOnboardingView: View {
    private typealias L10n = LocalizationConstants.RecurringBuy

    @BlockchainApp var app
    @Environment(\.scheduler) var scheduler

    public let location: RecurringBuyListView.Location

    public var asset: String {
        location.asset
    }

    private let pages: [RecurringBuyOnboardingScreens] = RecurringBuyOnboardingScreens.allCases
    @State private var currentPage: RecurringBuyOnboardingScreens = .intro

    public init(location: RecurringBuyListView.Location) {
        self.location = location
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                LottieView(
                    json: "pricechart".data(in: .componentLibrary),
                    loopMode: .playOnce,
                    playConfig: currentPage.lottiePageConfig()
                )
                .opacity(currentPage == .intro ? 0.2 : 1.0)
                .frame(height: 140)
                .padding(.top, 80)
                ZStack {
                    pagesContent
                    buttonsSection
                        .padding(.bottom, Spacing.padding6)
                }
            }
            header
        }
        .batch {
            set(blockchain.ux.recurring.buy.onboarding.article.plain.navigation.bar.button.close.tap.then.close, to: true)
        }
        .padding(.top, Spacing.padding2)
        .background(
            Color.semantic.light.ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.textSpacing) {
                Text(L10n.Onboarding.title)
                    .typography(.body2)
                    .foregroundColor(.semantic.title)
                Text(L10n.Onboarding.subtitle)
                    .typography(.paragraph1)
                    .foregroundColor(.semantic.text)
                    .opacity(currentPage == .intro ? 1.0 : 0.0)
            }
            Spacer()
            Button {
                $app.post(event: blockchain.ux.recurring.buy.onboarding.article.plain.navigation.bar.button.close.tap)
            } label: {
                Icon.close
                    .frame(width: 24, height: 24)
            }
        }
        .padding([.leading, .trailing], Spacing.padding2)
    }

    @ViewBuilder
    private var pagesContent: some View {
        TabView(
            selection: $currentPage.animation()
        ) {
            ForEach(pages) { page in
                page.makeView(app: app, assetId: asset)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    @ViewBuilder
    private var buttonsSection: some View {
        VStack(spacing: .zero) {
            Spacer()
            PageControl(
                controls: pages,
                selection: $currentPage.animation()
            )
            PrimaryButton(
                title: L10n.Onboarding.buttonTitle,
                action: {
                    Task { @MainActor [app] in
                        app.post(event: blockchain.ux.recurring.buy.onboarding.article.plain.navigation.bar.button.close.tap)
                        app.state.set(blockchain.ux.transaction["buy"].action.show.recurring.buy, to: true)
                        if case .dashboard = location {
                            app.post(event: blockchain.ux.recurring.buy.onboarding.entry.paragraph.button.primary.tap)
                        } else {
                            app.post(event: blockchain.ux.asset[asset].buy)
                        }
                    }
                }
            )
            .cornerRadius(Spacing.padding4)
            .batch {
                set(blockchain.ux.recurring.buy.onboarding.entry.paragraph.button.primary.tap.then.enter.into, to: blockchain.ux.transaction["buy"].select.target)
            }
        }
        .padding(.horizontal, Spacing.padding3)
    }
}

extension RecurringBuyOnboardingScreens {

    @ViewBuilder
    func makeView(app: AppProtocol, assetId: String) -> some View {
        VStack(alignment: .center, spacing: Spacing.padding3) {
            Group {
                Text(titles.main)
                    .foregroundColor(.semantic.title)
                +
                Text(titles.highlighted)
                    .foregroundColor(.semantic.primary)
            }
            .typography(.title3)
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            if let footnote {
                VStack(spacing: Spacing.textSpacing) {
                    Text(footnote)
                        .typography(.caption1)
                        .foregroundColor(.semantic.body)
                        .multilineTextAlignment(.center)
                    if let learnMoreLink, let url = URL(string: learnMoreLink) {
                        Button {
                            app.post(event: blockchain.ux.recurring.buy.onboarding.entry.paragraph.button.minimal.event.tap)
                        } label: {
                            Text(L10n.Onboarding.Pages.learnMore)
                                .typography(.caption1)
                                .foregroundColor(.semantic.primary)
                        }
                        .batch {
                            set(
                                blockchain.ux.recurring.buy.onboarding.entry.paragraph.button.minimal.event.tap.then.launch.url,
                                to: url
                            )
                        }
                    }
                }
            }
        }
        .padding([.leading, .trailing], Spacing.padding4)
    }
}
