// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import BlockchainUI
import ComposableArchitecture
import ComposableNavigation
import ErrorsUI
import FeatureAuthenticationDomain
import Localization
import SwiftUI
import UIComponentsKit

private typealias LocalizedString = LocalizationConstants.FeatureAuthentication.CreateAccount
private typealias AccessibilityIdentifier = AccessibilityIdentifiers.CreateAccountScreen

struct CreateAccountViewStepTwo: View {

    private let store: Store<CreateAccountStepTwoState, CreateAccountStepTwoAction>
    @ObservedObject private var viewStore: ViewStore<CreateAccountStepTwoState, CreateAccountStepTwoAction>
    @BlockchainApp var app
    @State private var focusedEmail = false
    @State private var focusedPassword = false
    @State private var focusedPasswordConfirmation = false

    init(store: Store<CreateAccountStepTwoState, CreateAccountStepTwoAction>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: Spacing.padding3) {
                    header
                    form
                    BlockchainComponentLibrary.PrimaryButton(
                        title: LocalizedString.createAccountButton,
                        isLoading: viewStore.validatingInput || viewStore.isCreatingWallet
                    ) {
                        viewStore.send(.createButtonTapped)
                    }
                    .disabled(viewStore.isCreateButtonDisabled)
                    .accessibility(identifier: AccessibilityIdentifier.createAccountButton)
                }
                .padding(Spacing.padding3)
                .frame(minHeight: geometry.size.height)
            }
            .onTapGesture {
                focusedEmail = false
                focusedPassword = false
                focusedPasswordConfirmation = false
            }
            .dismissKeyboardOnScroll()
            // setting the frame is necessary for the Spacer inside the VStack above to work properly
        }
        .primaryNavigation(title: "")
        .onAppear {
            $app.post(event: blockchain.ux.user.authentication.sign.up.enter.email.and.password)
        }
        .onAppear(perform: {
            viewStore.send(.onAppear)
        })
        .onWillDisappear {
            viewStore.send(.onWillDisappear)
        }
        .navigationRoute(in: store)
        .sheet(item: viewStore.$fatalError) { error in
            ErrorView(
                ux: error,
                navigationBarClose: true,
                fallback: {
                    ZStack {
                        Circle()
                            .fill(Color.semantic.light)
                            .frame(width: 88)
                        Icon.user
                            .color(.semantic.title)
                            .frame(width: 50)
                    }
                },
                dismiss: {
                    viewStore.send(.binding(.set(\.$fatalError, nil)))
                }
            )
        }
        .background(Color.semantic.light.ignoresSafeArea())
    }
}

extension CreateAccountViewStepTwo {

    var header: some View {
        VStack(spacing: Spacing.padding3) {
            Icon.user
                .color(.semantic.title)
                .with(length: 58.pt)
                .background(
                    Circle()
                        .fill(Color.semantic.background)
                        .frame(width: 88, height: 88)
                )
                .frame(width: 88, height: 88)
            VStack(spacing: Spacing.baseline) {
                Text(LocalizedString.headerTitle)
                    .typography(.title3)
                    .foregroundColor(.semantic.title)
                Text(LocalizedString.headerSubtitle)
                    .typography(.body1)
                    .foregroundColor(.semantic.body)
            }
        }
    }
}

extension CreateAccountViewStepTwo {

    var form: some View {
        VStack(spacing: Spacing.padding2) {
            emailField
            passwordField
            passwordConfirmationField
            Spacer()
            termsAgreementView
            if viewStore.shouldDisplayBakktTermsAndConditions {
                bakktTermsAgreementView
            }
        }
    }

    private var emailField: some View {
        let shouldShowError = viewStore.inputValidationState == .invalid(.invalidEmail)
        return Input(
            text: viewStore.$emailAddress,
            isFirstResponder: $focusedEmail,
            shouldResignFirstResponderOnReturn: true,
            label: LocalizedString.TextFieldTitle.email,
            subText: shouldShowError ? LocalizedString.TextFieldError.invalidEmail : nil,
            subTextStyle: .error,
            placeholder: LocalizedString.TextFieldPlaceholder.email,
            state: shouldShowError ? .error : .default
        )
        .accessibility(identifier: AccessibilityIdentifier.emailGroup)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
    }

    private var passwordField: some View {
        let shouldShowError = viewStore.passwordRulesBreached.isNotEmpty
        return VStack {
            Input(
                text: viewStore.$password,
                isFirstResponder: $focusedPassword,
                shouldResignFirstResponderOnReturn: true,
                label: LocalizedString.TextFieldTitle.password,
                subText: viewStore.password.isEmpty ? nil : viewStore.passwordRulesBreached.hint,
                subTextStyle: viewStore.password.isEmpty ? .primary : viewStore.passwordRulesBreached.inputSubTextStyle,
                placeholder: LocalizedString.TextFieldPlaceholder.password,
                state: shouldShowError ? .error : .default,
                isSecure: !viewStore.passwordFieldTextVisible,
                trailing: {
                    PasswordEyeSymbolButton(
                        isPasswordVisible: viewStore.$passwordFieldTextVisible
                    )
                }
            )
            .accessibility(identifier: AccessibilityIdentifier.passwordGroup)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode) // Disables strong password suggestions

            Text(PasswordValidationRule.displayString) { string in
                string.foregroundColor = .semantic.body

                for rule in viewStore.passwordRulesBreached {
                    if let range = string.range(of: rule.accent) {
                        string[range].foregroundColor = .semantic.error
                    }
                }
            }
            .typography(.caption1)
        }
    }

    private var passwordConfirmationField: some View {
        let shouldShowError = viewStore.inputConfirmationValidationState == .invalid(.passwordsDontMatch)
        return Input(
            text: viewStore.$passwordConfirmation,
            isFirstResponder: $focusedPasswordConfirmation,
            shouldResignFirstResponderOnReturn: true,
            label: LocalizedString.TextFieldTitle.passwordConfirmation,
            subText: shouldShowError ? LocalizedString.TextFieldError.passwordsDontMatch : nil,
            subTextStyle: .error,
            placeholder: LocalizedString.TextFieldPlaceholder.passwordConfirmation,
            state: shouldShowError ? .error : .default,
            isSecure: !viewStore.passwordFieldTextVisible,
            trailing: {
                PasswordEyeSymbolButton(
                    isPasswordVisible: viewStore.$passwordFieldTextVisible
                )
            }
        )
        .accessibility(identifier: AccessibilityIdentifier.passwordGroup)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.password)
    }

    private var termsAgreementView: some View {
        Text(LocalizedStringKey(LocalizedString.agreementPrompt))
            .typography(.micro)
            .foregroundColor(.semantic.body)
            .multilineTextAlignment(.center)
            .accessibility(identifier: AccessibilityIdentifier.agreementPromptText)
            // fixing the size prevents the view from collapsing when the keyboard is on screen
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bakktTermsAgreementView: some View {
        HStack(spacing: Spacing.baseline) {
            Toggle(isOn: viewStore.$bakktTermsAccepted) {}
                .labelsHidden()
                .accessibility(identifier: AccessibilityIdentifier.bakktTermsOfServiceButton)
            bakktAgreementText
                .typography(.micro)
                .accessibility(identifier: AccessibilityIdentifier.bakktAgreementPromptText)
        }
        // fixing the size prevents the view from collapsing when the keyboard is on screen
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bakktAgreementText: some View {
        HStack {
            VStack(alignment: .leading, spacing: .zero) {
                let promptText = Text(
                    rich: LocalizedString.bakktAgreementPrompt
                )
                promptText
                    .foregroundColor(.semantic.body)
                    .accessibility(identifier: AccessibilityIdentifier.agreementPromptText)

                HStack(alignment: .firstTextBaseline, spacing: .zero) {
                    Text(LocalizedString.bakktUserAgreementLink)
                        .foregroundColor(.semantic.primary)
                        .onTapGesture {
                            $app.post(event: blockchain.ux.bakkt.terms)
                        }
                        .accessibility(identifier: AccessibilityIdentifier.termsOfServiceButton)
                        .batch {
                            set(blockchain.ux.bakkt.terms.then.launch.url, to: { blockchain.ux.bakkt.terms.url })
                        }
                }
            }
            Spacer()
        }
    }
}

extension PasswordValidationRule {
    public var displayString: String {
        switch self {
        case .lowercaseLetter:
            return LocalizedString.Password.Rules.Lowercase.display
        case .uppercaseLetter:
            return LocalizedString.Password.Rules.Uppercase.display
        case .number:
            return LocalizedString.Password.Rules.Number.display
        case .specialCharacter:
            return LocalizedString.Password.Rules.SpecialCharacter.display
        case .length:
            return LocalizedString.Password.Rules.Length.display
        }
    }

    public var accent: String {
        switch self {
        case .lowercaseLetter:
            return LocalizedString.Password.Rules.Lowercase.display
        case .uppercaseLetter:
            return LocalizedString.Password.Rules.Uppercase.display
        case .number:
            return LocalizedString.Password.Rules.Number.display
        case .specialCharacter:
            return LocalizedString.Password.Rules.SpecialCharacter.display
        case .length:
            return LocalizedString.Password.Rules.Length.accent
        }
    }

    public static let displayString: String = {
        let rules = PasswordValidationRule.all.map(\.displayString).joined(separator: ", ")
        return LocalizedString.Password.Rules.prefix + rules
    }()
}

extension Text {
    public init(_ string: String, configure: (inout AttributedString) -> Void) {
        var attributedString = AttributedString(string) /// create an `AttributedString`
        configure(&attributedString) /// configure using the closure
        self.init(attributedString) /// initialize a `Text`
    }
}

extension Collection<PasswordValidationRule> {

    public var hint: String {
        isEmpty ? LocalizedString.Password.Rules.secure : LocalizedString.Password.Rules.insecure
    }

    public var inputSubTextStyle: InputSubTextStyle {
        isEmpty ? .success : .error
    }
}

struct DismissKeyboard: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

extension View {

    func dismissKeyboardOnScroll() -> some View {
        modifier(DismissKeyboard())
    }
}

#if DEBUG
import AnalyticsKit
import ToolKit

struct CreateAccountViewStepTwo_Previews: PreviewProvider {

    static var previews: some View {
        CreateAccountViewStepTwo(
            store: Store(
                initialState: .init(
                    context: .createWallet,
                    country: SearchableItem(id: "1", title: "US"),
                    countryState: SearchableItem(id: "1", title: "State"),
                    referralCode: "id1"
                ),
                reducer: {
                    CreateAccountStepTwoReducer(
                        mainQueue: .main,
                        passwordValidator: PasswordValidator(),
                        externalAppOpener: ToLogAppOpener(),
                        analyticsRecorder: NoOpAnalyticsRecorder(),
                        walletRecoveryService: .noop,
                        walletCreationService: .noop,
                        walletFetcherService: .noop,
                        recaptchaService: NoOpGoogleRecatpchaService()
                    )
                }
            )
        )
    }
}
#endif
