// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainNamespace
import BlockchainUI
import ComposableArchitecture
import Localization
import SwiftUI
import UnifiedActivityDomain
import UnifiedActivityUI

public struct ActivityDetailSceneView: View {
    @BlockchainApp var app
    @Environment(\.context) var context
    let store: StoreOf<ActivityDetailScene>

    @State private var scrollOffset: CGPoint = .zero

    struct ViewState: Equatable {
        let items: ActivityDetail.GroupedItems?
        let isPlaceholder: Bool
        let isExternalTradingEnabled: Bool

        init(state: ActivityDetailScene.State) {
            self.items = state.items
            self.isPlaceholder = state.items == state.placeholderItems
            self.isExternalTradingEnabled = state.isExternalTradingEnabled
        }
    }

    public init(store: StoreOf<ActivityDetailScene>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: ViewState.init(state:)) { viewStore in
            ScrollView {
                VStack {
                    if let groups = viewStore.items {
                        ForEach(groups.itemGroups) { item in
                            VStack(spacing: 0) {
                                ForEach(item.itemGroup) { itemType in
                                    Group {
                                        ActivityRow(itemType: itemType)
                                        if itemType.id != item.itemGroup.last?.id {
                                            PrimaryDivider()
                                        }
                                    }
                                }
                            }
                            .cornerRadius(16)
                            .padding(.horizontal, Spacing.padding2)
                            .padding(.bottom)
                        }
                        .redacted(reason: viewStore.isPlaceholder ? .placeholder : [])
                    }

                    if viewStore.isExternalTradingEnabled {
                        bakktBottomView()
                    }

                    if let floatingActions = viewStore.items?.floatingActions {
                        VStack {
                            ForEach(floatingActions) { actionButton in
                                FloatingButton(button: actionButton)
                                    .context([blockchain.ux.activity.detail.floating.button.id: actionButton.id])
                            }
                        }
                        .padding(.horizontal, Spacing.padding2)
                    }
                }
                .scrollOffset($scrollOffset)
                .padding(.top, Spacing.padding3)
                .frame(maxHeight: .infinity)
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .navigationBarHidden(true)
            }
            .superAppNavigationBar(
                title: {
                    navigationTitleView(
                        title: viewStore.items?.title,
                        icon: viewStore.items?.icon
                    )
                    .redacted(reason: viewStore.isPlaceholder ? .placeholder : [])
                },
                trailing: { navigationTrailingView() },
                scrollOffset: $scrollOffset.y
            )
            .background(Color.semantic.light.ignoresSafeArea(edges: .bottom))
        }
    }

    struct FloatingButton: View {
        let tag = blockchain.ux.activity.detail.floating.button

        @BlockchainApp var app
        let button: ActivityItem.Button

        var body: some View {
            Group {
                switch button.style {
                case .primary:
                    PrimaryButton(title: button.text) {
                        $app.post(event: tag.tap)
                    }
                case .secondary:
                    SecondaryButton(title: button.text) {
                        $app.post(event: tag.tap)
                    }
                }
            }
            .batch {
                set(tag.tap, to: button.action)
            }
        }
    }

    @ViewBuilder
    func navigationTitleView(title: String?, icon: ImageType?) -> some View {
        HStack(spacing: Spacing.padding1) {
            imageView(with: icon)
            Text(title ?? "")
                .typography(.body2)
                .foregroundColor(.semantic.title)
        }
    }

    public func navigationTrailingView() -> some View {
        IconButton(icon: .navigationCloseButton()) {
            $app.post(event: blockchain.ux.activity.detail.article.plain.navigation.bar.button.close.tap)
        }
        .frame(width: 24.pt, height: 24.pt)
        .batch {
            set(blockchain.ux.activity.detail.article.plain.navigation.bar.button.close.tap.then.close, to: true)
        }
    }

    @ViewBuilder
    func bakktBottomView() -> some View {
        VStack {
            VStack(alignment: .leading) {
                bakktDisclaimer()
                SmallMinimalButton(title: LocalizationConstants.Activity.Details.Button.viewDisclosures) {
                    $app.post(event: blockchain.ux.bakkt.view.disclosures)
                }
                .batch {
                    set(blockchain.ux.bakkt.view.disclosures.then.launch.url, to: "https://bakkt.com/disclosures")
                }
            }

            Image("bakkt-logo", bundle: .componentLibrary)
                .foregroundColor(.semantic.title)
                .padding(.top, Spacing.padding2)
        }
        .padding(.horizontal, Spacing.padding2)
    }

    @ViewBuilder
    func bakktDisclaimer() -> some View {
        let label = LocalizationConstants.Activity.Details.bakktDisclaimer
        Text(rich: label)
            .typography(.caption1)
            .foregroundColor(.semantic.body)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private func imageView(with image: ImageType?) -> some View {
        ActivityRowImage(image: image)
    }
}

extension ItemType: Identifiable {
    public var id: String {
        switch self {
        case .compositionView(let compositionView):
            return compositionView.leading.reduce(into: "") { partialResult, item in
                partialResult += item.id
            }

        case .leaf(let ItemType):
            return ItemType.id
        }
    }
}
