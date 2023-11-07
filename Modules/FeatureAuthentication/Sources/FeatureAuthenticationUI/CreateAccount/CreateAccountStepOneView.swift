// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainUI
import ComposableArchitecture
import ComposableNavigation
import FeatureAuthenticationDomain
import Localization
import SwiftUI
import UIComponentsKit

private typealias LocalizedString = LocalizationConstants.FeatureAuthentication.CreateAccount
private typealias AccessibilityIdentifier = AccessibilityIdentifiers.CreateAccountScreen

struct CreateAccountStepOneView: View {

    @BlockchainApp var app

    private let store: Store<CreateAccountStepOneState, CreateAccountStepOneAction>
    @ObservedObject private var viewStore: ViewStore<CreateAccountStepOneState, CreateAccountStepOneAction>

    init(store: Store<CreateAccountStepOneState, CreateAccountStepOneAction>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: Spacing.padding3) {
                    CreateAccountHeader()
                    CreateAccountForm(viewStore: viewStore)
                    Spacer()
                    BlockchainComponentLibrary.PrimaryButton(
                        title: LocalizedString.nextButton,
                        isLoading: viewStore.validatingInput || viewStore.isCreatingWallet
                    ) {
                        viewStore.send(.nextStepButtonTapped)
                    }
                    .disabled(viewStore.isNextStepButtonDisabled)
                    .accessibility(identifier: AccessibilityIdentifier.nextButton)
                }
                .padding(Spacing.padding3)
                // setting the frame is necessary for the Spacer inside the VStack above to work properly
                .frame(height: geometry.size.height)
            }
        }
        .primaryNavigation(title: "") {
            Button {
                viewStore.send(.nextStepButtonTapped)
            } label: {
                Text(LocalizedString.nextButton)
                    .typography(.paragraph2)
            }
            .disabled(viewStore.isNextStepButtonDisabled)
            // disabling the button doesn't gray it out
            .foregroundColor(viewStore.isNextStepButtonDisabled ? .semantic.muted : .semantic.title)
            .accessibility(identifier: AccessibilityIdentifier.nextButton)
        }
        .onAppear {
            $app.post(event: blockchain.ux.user.authentication.sign.up.select.country)
        }
        .onAppear(perform: {
            viewStore.send(.onAppear)
        })
        .onWillDisappear {
            viewStore.send(.onWillDisappear)
        }
        .navigationRoute(in: store)
        .alert(
            store: store.scope(
                state: \.$failureAlert,
                action: { .alert($0) }
            )
        )
        .background(Color.semantic.light.ignoresSafeArea())
    }
}

private struct CreateAccountHeader: View {

    var body: some View {
        VStack(spacing: Spacing.padding3) {
            Icon.globe
                .color(.semantic.title)
                .with(length: 58.pt)
                .background(
                    Circle()
                        .fill(Color.semantic.background)
                        .frame(width: 88, height: 88)
                )
                .frame(width: 88, height: 88)
            VStack(spacing: Spacing.baseline) {
                Text(LocalizedString.Step1.headerTitle)
                    .typography(.title3)
                Text(LocalizedString.Step1.headerSubtitle)
                    .typography(.body1)
                    .foregroundColor(.semantic.body)
            }
        }
    }
}

private struct CreateAccountForm: View {

    @ObservedObject var viewStore: ViewStore<CreateAccountStepOneState, CreateAccountStepOneAction>

    var body: some View {
        VStack(spacing: Spacing.padding2) {
            countryAndStatePickers
            referralCodeField
        }
    }

    private var countryAndStatePickers: some View {
        VStack(alignment: .leading, spacing: Spacing.baseline) {
            let accessory = Icon.chevronDown
                .color(.semantic.muted)
                .frame(width: 12, height: 12)

            Text(LocalizedString.TextFieldTitle.country)
                .typography(.paragraph2)

                let isCountryValid = viewStore.inputValidationState != .invalid(.noCountrySelected)
                if viewStore.shouldDisplayCountryStateField {
                    let isCountryStateValid = viewStore.inputValidationState != .invalid(.noCountryStateSelected)
                    PrimaryPicker(
                        selection: viewStore.$selectedAddressSegmentPicker,
                        rows: [
                            .row(
                                title: viewStore.country?.title,
                                identifier: .country,
                                placeholder: LocalizedString.TextFieldPlaceholder.country,
                                inputState: isCountryValid ? .default : .error,
                                trailing: { accessory }
                            )
                        ]
                    )
                    Text(LocalizedString.TextFieldTitle.state)
                        .typography(.paragraph2)
                        .padding(.top, Spacing.padding2)
                    PrimaryPicker(
                        selection: viewStore.$selectedAddressSegmentPicker,
                        rows: [
                            .row(
                                title: viewStore.countryState?.title,
                                identifier: .countryState,
                                placeholder: LocalizedString.TextFieldPlaceholder.state,
                                inputState: isCountryStateValid ? .default : .error,
                                trailing: { accessory }
                            )
                        ]
                    )
                } else {
                    PrimaryPicker(
                        selection: viewStore.$selectedAddressSegmentPicker,
                        rows: [
                            .row(
                                title: viewStore.country?.title,
                                identifier: .country,
                                placeholder: LocalizedString.TextFieldPlaceholder.country,
                                inputState: isCountryValid ? .default : .error,
                                trailing: { accessory }
                            )
                        ]
                    )
                }
        }
    }

    private var referralCodeField: some View {
        var subText: String?
        var subTextStlye: InputSubTextStyle = InputSubTextStyle.default
        let shouldShowError = viewStore.referralCodeValidationState == .invalid(.invalidReferralCode)
        if viewStore.referralCodeValidationState == .invalid(.invalidReferralCode) {
            subText = LocalizedString.TextFieldError.invalidReferralCode
            subTextStlye = .error
        } else if viewStore.referralCodeValidationState == .valid {
            subText = LocalizedString.TextFieldError.referralCodeApplied
            subTextStlye = .success
        }
        return Input(
            text: viewStore.$referralCode,
            isFirstResponder: viewStore
                .$selectedInputField
                .equals(.referralCode),
            label: LocalizedString.TextFieldTitle.referral,
            subText: subText,
            subTextStyle: subTextStlye,
            placeholder: LocalizedString.TextFieldPlaceholder.referralCode,
            characterLimit: 8,
            state: shouldShowError ? .error : .default,
            onReturnTapped: {
                viewStore.send(.set(\.$selectedInputField, nil))
            }
        )
        .accessibility(identifier: AccessibilityIdentifier.referralGroup)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .keyboardType(.default)
    }
}

#if DEBUG
import AnalyticsKit
import BlockchainNamespace
import ToolKit

struct CreateAccountStepOneView_Previews: PreviewProvider {

    static var previews: some View {
        PrimaryNavigationView {
            CreateAccountStepOneView(
                store: Store(
                    initialState: .init(
                        context: .createWallet
                    ),
                    reducer: {
                        CreateAccountStepOneReducer(
                            mainQueue: .main,
                            passwordValidator: NoOpPasswordValidator(),
                            externalAppOpener: ToLogAppOpener(),
                            analyticsRecorder: NoOpAnalyticsRecorder(),
                            walletRecoveryService: .noop,
                            walletCreationService: .noop,
                            walletFetcherService: .noop,
                            signUpCountriesService: NoSignUpCountriesService(),
                            recaptchaService: NoOpGoogleRecatpchaService(),
                            app: App.preview
                        )
                    }
                )
            )
        }
    }
}

class NoSignUpCountriesService: SignUpCountriesServiceAPI {

    init() {}

    var countries: AnyPublisher<[Country], Error> {
        .empty()
    }
}

#endif
