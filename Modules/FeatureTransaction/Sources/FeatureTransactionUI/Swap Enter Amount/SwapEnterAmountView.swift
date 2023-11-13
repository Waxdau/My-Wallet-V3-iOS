import BlockchainComponentLibrary
import BlockchainNamespace
import ComposableArchitecture
import FeatureTransactionDomain
import Localization
import PlatformUIKit
import RxSwift
import SwiftUI

public struct SwapEnterAmountView: View {
    @BlockchainApp var app
    let store: StoreOf<SwapEnterAmount>
    @ObservedObject var viewStore: ViewStore<SwapEnterAmount.State, SwapEnterAmount.Action>
    public init(store: StoreOf<SwapEnterAmount>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    public var body: some View {
        ZStack {
            Color.semantic.light
            VStack {
                Spacer()
                valuesContainer(viewStore)
                maxButton
                Spacer()
                ZStack(alignment: .center) {
                    HStack(spacing: Spacing.padding1, content: {
                        fromView
                            .cornerRadius(16, corners: .allCorners)
                        targetView
                            .cornerRadius(16, corners: .allCorners)
                    })
                    .padding(.horizontal, Spacing.padding2)

                    Icon
                        .arrowRight
                        .color(.semantic.title)
                        .small()
                        .padding(2)
                        .background(Color.semantic.background)
                        .clipShape(Circle())
                        .padding(Spacing.padding1)
                        .background(Color.semantic.light)
                        .clipShape(Circle())
                }

                previewSwapButton
                    .padding(Spacing.padding2)


                DigitPadViewSwiftUI(
                    inputValue: viewStore.binding(get: \.input.suggestion, send: SwapEnterAmount.Action.onInputChanged),
                    backspace: { viewStore.send(.onBackspace) }
                )
                .frame(height: 230)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewStore.send(.onAppear)
        }
        .sheet(isPresented: viewStore.$showAccountSelect, content: {
            IfLetStore(
                store.scope(
                    state: \.selectFromCryptoAccountState,
                    action: SwapEnterAmount.Action.onSelectFromCryptoAccountAction
                ),
                then: { store in
                    SwapFromAccountSelectView(store: store)
                }
            )

            IfLetStore(
                store.scope(
                    state: \.selectToCryptoAccountState,
                    action: SwapEnterAmount.Action.onSelectToCryptoAccountAction
                ),
                then: { store in
                    SwapToAccountSelectView(store: store)
                }
            )
        })
        .bindings {
            subscribe(
                viewStore.$sourceValuePrice,
                to: blockchain.api.nabu.gateway.price.crypto[viewStore.sourceInformation?.currency.code].fiat[{ blockchain.user.currency.preferred.fiat.trading.currency }].quote.value
            )
        }
        .bindings {
            subscribe(
                viewStore.$defaultFiatCurrency,
                to: blockchain.user.currency.preferred.fiat.trading.currency
            )
        }
    }

    @ViewBuilder
    func valuesContainer(
        _ viewStore: ViewStoreOf<SwapEnterAmount>
    ) -> some View {
        ZStack(alignment: .trailing) {
            HStack(alignment: .center) {
                VStack {
                    Text(viewStore.mainFieldText)
                        .typography(.display)
                        .lineLimit(1)
                        .foregroundColor(.semantic.title)
                        .minimumScaleFactor(0.1)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.1), value: viewStore.isEnteringFiat)
                    Text(viewStore.secondaryFieldText)
                        .typography(.subheading)
                        .foregroundColor(.semantic.text)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.1), value: viewStore.isEnteringFiat)
                }
                .padding(.trailing, Spacing.padding3)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            inputSectionFlipButton(viewStore)
        }
    }

    @ViewBuilder
    private var maxButton: some View {
        if let label = viewStore.maxAmountToSwapLabel {
            SmallMinimalButton(title: String(format: LocalizationConstants.Swap.maxString, label)) {
                viewStore.send(.onMaxButtonTapped)
            }
        }
    }

    @MainActor
    private var fromView: some View {
        HStack {
            if let sourceInformation = viewStore.sourceInformation {
                sourceInformation.currency.logo()
            } else {
                Icon
                    .selectPlaceholder
                    .color(.semantic.title)
                    .small()
            }

            VStack(alignment: .leading, content: {
                Text(viewStore.sourceInformation?.currency.assetModel.name ?? "From")
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)

                Text(viewStore.sourceInformation?.currency.assetModel.code ?? "Select")
                    .typography(.paragraph1)
                    .foregroundColor(.semantic.body)
            })
            Spacer()
        }
        .frame(height: 77.pt)
        .padding(.leading, Spacing.padding2)
        .background(Color.semantic.background)
        .onTapGesture {
            viewStore.send(.onSelectSourceTapped)
        }
    }

    @MainActor
    private var targetView: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, content: {
                Text(viewStore.targetInformation?.currency.assetModel.name ?? "To")
                    .typography(.paragraph2)
                    .foregroundColor(.semantic.title)

                Text(viewStore.targetInformation?.currency.assetModel.code ?? "Select")
                    .typography(.paragraph1)
                    .foregroundColor(.semantic.body)
            })

            if let targetInformation = viewStore.targetInformation {
                targetInformation.currency.logo()
            } else {
                Icon
                    .selectPlaceholder
                    .color(.semantic.title)
                    .small()
            }
        }
        .frame(height: 77.pt)
        .padding(.trailing, Spacing.padding2)
        .background(Color.semantic.background)
        .onTapGesture {
            viewStore.send(.onSelectTargetTapped)
        }
    }

    private func inputSectionFlipButton(
        _ viewStore: ViewStoreOf<SwapEnterAmount>
    ) -> some View {
        Button(
            action: {
                viewStore.send(.onChangeInputTapped)
            },
            label: {
                ZStack {
                    Circle()
                        .frame(width: 40)
                        .foregroundColor(Color.semantic.light)
                    Icon.unfoldMore
                        .color(.semantic.title)
                        .circle(backgroundColor: .semantic.background)
                        .small()
                }
            }
        )
    }

    @ViewBuilder
    private var previewSwapButton: some View {
        if viewStore.transactionDetails.forbidden {
            SecondaryButton(title: viewStore.transactionDetails.ctaLabel,
                            isLoading: viewStore.isLoading,
                            action: {
                if let transactionError = viewStore.transactionError {
                    $app.post(
                        event: blockchain.ux.tooltip.entry.paragraph.button.minimal.tap,
                        context: [
                            blockchain.ux.tooltip.title: transactionError.recoveryWarningTitle(for: .swap) ?? "N/A",
                            blockchain.ux.tooltip.body: transactionError.recoveryWarningMessage(for: .swap),
                            blockchain.ui.type.action.then.enter.into.detents: [
                                blockchain.ui.type.action.then.enter.into.detents.automatic.dimension
                            ]
                        ]
                    )
                }
            })
            .transition(.opacity)
            .batch {
                set(blockchain.ux.tooltip.entry.paragraph.button.minimal.tap.then.enter.into, to: blockchain.ux.tooltip)
            }
        } else {
            PrimaryButton(title: viewStore.transactionDetails.ctaLabel, 
                          isLoading: viewStore.isLoading, action: {
                viewStore.send(.onPreviewTapped)
            })
            .transition(.opacity)
            .disabled(viewStore.previewButtonDisabled)
        }
    }
}

struct DigitPadViewSwiftUI: UIViewRepresentable {
    typealias UIViewType = DigitPadView
    @Binding var inputValue: String
    var backspace: () -> Void
    private let disposeBag = DisposeBag()

    func makeUIView(context: Context) -> DigitPadView {
        let view = DigitPadView()
        view.viewModel = provideDigitPadViewModel()
        view.viewModel
            .valueRelay
            .subscribe(onNext: { text in
                inputValue = text
            })
            .disposed(by: disposeBag)

        view.viewModel
            .backspaceButtonTapObservable
            .subscribe(onNext: { _ in
                backspace()
            })
            .disposed(by: disposeBag)

        return view
    }

    func updateUIView(_ uiView: DigitPadView, context: Context) {}

    private func provideDigitPadViewModel() -> DigitPadViewModel {
        let highlightColor = UIColor.black.withAlphaComponent(0.08)
        let model = DigitPadButtonViewModel(
            content: .label(text: MoneyValueInputScanner.Constant.decimalSeparator, tint: .titleText),
            background: .init(highlightColor: highlightColor)
        )
        return DigitPadViewModel(
            padType: .number,
            customButtonViewModel: model,
            contentTint: .semantic.title,
            buttonHighlightColor: highlightColor,
            backgroundColor: .semantic.light
        )
    }
}
