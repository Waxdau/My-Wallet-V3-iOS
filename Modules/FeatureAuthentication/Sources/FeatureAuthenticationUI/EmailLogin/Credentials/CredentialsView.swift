// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import Blockchain
import BlockchainComponentLibrary
import ComposableArchitecture
import ComposableNavigation
import FeatureAuthenticationDomain
import Localization
import SwiftUI
import ToolKit
import UIComponentsKit

public enum CredentialsRoute: NavigationRoute {
    case seedPhrase
    case secondPasswordDetected

    @ViewBuilder
    public func destination(in store: Store<CredentialsState, CredentialsAction>) -> some View {
        switch self {
        case .seedPhrase:
            IfLetStore(
                store.scope(
                    state: \.seedPhraseState,
                    action: CredentialsAction.seedPhrase
                ),
                then: SeedPhraseView.init(store:)
            )
        case .secondPasswordDetected:
            IfLetStore(
                store.scope(
                    state: \.secondPasswordNoticeState,
                    action: CredentialsAction.secondPasswordNotice
                ),
                then: SecondPasswordNoticeView.init(store:)
            )
        }
    }
}

public struct CredentialsView: View {

    private typealias LocalizedString = LocalizationConstants.FeatureAuthentication.EmailLogin

    private enum Layout {
        static let topPadding: CGFloat = 34
        static let bottomPadding: CGFloat = 34
        static let leadingPadding: CGFloat = 24
        static let trailingPadding: CGFloat = 24

        static let resetTwoFATextSpacing: CGFloat = 2
        static let troubleLogInTextTopPadding: CGFloat = 1
        static let linkTextFontSize: CGFloat = 14
        static let textFieldBottomPadding: CGFloat = 20
    }

    private let context: CredentialsContext
    private let store: Store<CredentialsState, CredentialsAction>
    @ObservedObject private var viewStore: ViewStore<CredentialsState, CredentialsAction>

    private var twoFATitle: String {
        switch viewStore.twoFAState?.twoFAType {
        case nil, .standard, .email:
            ""
        case .sms:
            LocalizedString.TextFieldTitle.smsCode
        case .google:
            LocalizedString.TextFieldTitle.authenticatorCode
        case .yubiKey, .yubikeyMtGox:
            LocalizedString.TextFieldTitle.hardwareKeyCode
        }
    }

    private var twoFAErrorMessage: String {
        guard !viewStore.isAccountLocked else {
            return LocalizedString.TextFieldError.accountLocked
        }
        guard let twoFAState = viewStore.twoFAState,
              twoFAState.isTwoFACodeIncorrect
        else {
            return ""
        }
        switch twoFAState.twoFACodeIncorrectContext {
        case .incorrect:
            return String(
                format: LocalizedString.TextFieldError.incorrectTwoFACode,
                viewStore.twoFAState?.twoFACodeAttemptsLeft ?? 0
            )
        case .missingCode:
            return LocalizedString.TextFieldError.missingTwoFACode
        case .none:
            return ""
        }
    }

    @State private var isWalletIdentifierFirstResponder: Bool = false
    @State private var isPasswordFieldFirstResponder: Bool = false
    @State private var isTwoFAFieldFirstResponder: Bool = false
    @State private var isPasswordVisible: Bool = false
    @State private var isHardwareKeyVisible: Bool = false

    public init(context: CredentialsContext, store: Store<CredentialsState, CredentialsAction>) {
        self.context = context
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading) {
                    emailOrWalletIdentifierView()
                        .padding(.bottom, Layout.textFieldBottomPadding)

                    passwordField
                        .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.passwordGroup)

                    Button(
                        action: {
                            disableAnyFocusedFields()
                            viewStore.send(.onForgotPasswordTapped)
                        },
                        label: {
                            Text(LocalizedString.Link.forgotPasswordLink)
                                .typography(.paragraph1)
                                .foregroundColor(.semantic.primary)
                        }
                    )
                    .padding(.top, Layout.troubleLogInTextTopPadding)
                    .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.troubleLoggingInButton)

                    if let state = viewStore.twoFAState, state.isTwoFACodeFieldVisible {
                        twoFAField
                            .padding(.top, Layout.textFieldBottomPadding)
                            .padding(.bottom, Layout.troubleLogInTextTopPadding)
                            .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.twoFAGroup)

                        if let state = viewStore.twoFAState, state.isResendSMSButtonVisible {
                            Button(
                                action: {
                                    disableAnyFocusedFields()
                                    viewStore.send(.walletPairing(.resendSMSCode))
                                },
                                label: {
                                    Text(LocalizedString.Button.resendSMS)
                                        .typography(.paragraph1)
                                        .foregroundColor(.semantic.primary)
                                }
                            )
                            .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.resendSMSButton)
                        }

                        if viewStore.twoFAState?.twoFAType == .yubiKey || viewStore.twoFAState?.twoFAType == .yubikeyMtGox {
                            Text(LocalizedString.TextFieldFootnote.hardwareKeyInstruction)
                                .typography(.paragraph1)
                                .foregroundColor(.semantic.text)
                        }

                        HStack(spacing: Layout.resetTwoFATextSpacing) {
                            Text(LocalizedString.TextFieldFootnote.lostTwoFACodePrompt)
                                .typography(.paragraph1)
                                .foregroundColor(.semantic.text)
                            Button(
                                action: {
                                    guard let url = URL(string: Constants.HostURL.resetTwoFA) else { return }
                                    UIApplication.shared.open(url)
                                },
                                label: {
                                    Text(LocalizedString.Link.resetTwoFALink)
                                        .typography(.paragraph1)
                                        .foregroundColor(.semantic.primary)
                                }
                            )
                        }
                        .padding(.top, 0.5)
                        .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.resetTwoFAButton)
                    }

                    Spacer()

                    PrimaryButton(
                        title: LocalizedString.Button._continue,
                        isLoading: viewStore.isLoading
                    ) {
                        disableAnyFocusedFields()
                        viewStore.send(.continueButtonTapped)
                    }
                    .disabled(viewStore.isLoading || viewStore.walletPairingState.walletGuid.isEmpty)
                }
                .padding(
                    EdgeInsets(
                        top: Layout.topPadding,
                        leading: Layout.leadingPadding,
                        bottom: Layout.bottomPadding,
                        trailing: Layout.trailingPadding
                    )
                )
                .frame(minHeight: geometry.size.height)
            }
        }
        .navigationRoute(in: store)
        .primaryNavigation(title: LocalizedString.navigationTitle) {
            Button {
                isWalletIdentifierFirstResponder = false
                isPasswordFieldFirstResponder = false
                isTwoFAFieldFirstResponder = false
                viewStore.send(.set(\.$supportSheetShown, true))
            } label: {
                Icon
                    .questionFilled
                    .color(.semantic.muted)
                    .frame(width: 24, height: 24)
            }
            .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.nextButton)
        }
        .bottomSheet(
            isPresented: viewStore.$supportSheetShown,
            content: {
                IfLetStore(
                    store.scope(
                        state: \.customerSupportState,
                        action: CredentialsAction.customerSupport
                    ),
                    then: SupportView.init(store:)
                )
            }
        )
        .onAppear {
            viewStore.send(.didAppear(context: context))
        }
        .onWillDisappear {
            viewStore.send(.onWillDisappear)
        }
        .alert(
            store: store.scope(
                state: \.$credentialsFailureAlert,
                action: { .alert($0) }
            )
        )
        .background(Color.semantic.light.ignoresSafeArea())
    }

    // MARK: - Private

    @ViewBuilder
    private func emailOrWalletIdentifierView() -> some View {
        switch context {
        case .walletInfo(let info):
            emailTextfield(info: info)
        case .walletIdentifier,
             .manualPairing:
            walletIdentifierTextfield()
        case .none:
            Divider().overlay(Color.clear)
        }
    }

    private func emailTextfield(info: WalletInfo) -> some View {
        Input(
            text: .constant(viewStore.walletPairingState.emailAddress),
            isFirstResponder: .constant(false),
            shouldResignFirstResponderOnReturn: true,
            label: LocalizedString.TextFieldTitle.email,
            subText: LocalizedString.TextFieldFootnote.wallet + viewStore.walletPairingState.walletGuid,
            placeholder: viewStore.walletPairingState.emailAddress
        )
        .disabled(true)
        .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.emailGuidGroup)
    }

    private func walletIdentifierTextfield() -> some View {
        Input(
            text: viewStore.binding(
                get: { $0.walletPairingState.walletGuid },
                send: { .didChangeWalletIdentifier($0) }
            ),
            isFirstResponder: $isWalletIdentifierFirstResponder,
            label: LocalizedString.TextFieldTitle.walletIdentifier,
            state: viewStore.isWalletIdentifierIncorrect ? .error : .default,
            onReturnTapped: {
                isWalletIdentifierFirstResponder = false
                isPasswordFieldFirstResponder = true
                isTwoFAFieldFirstResponder = false
            }
        )
        .accessibility(identifier: AccessibilityIdentifiers.CredentialsScreen.guidGroup)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.username)
        .submitLabel(.next)
    }

    private var passwordField: some View {
        Input(
            text: viewStore.binding(
                get: \.passwordState.password,
                send: { .password(.didChangePassword($0)) }
            ),
            isFirstResponder: $isPasswordFieldFirstResponder,
            label: LocalizedString.TextFieldTitle.password,
            subText: viewStore.passwordFieldErrorMessage,
            subTextStyle: viewStore.passwordFieldErrorMessage.isNotNil ? .error : .default,
            state: (viewStore.passwordState.isPasswordIncorrect || viewStore.isAccountLocked) ? .error : .default,
            isSecure: !isPasswordVisible,
            trailing: {
                PasswordEyeSymbolButton(isPasswordVisible: $isPasswordVisible)
            },
            onReturnTapped: {
                isWalletIdentifierFirstResponder = false
                isPasswordFieldFirstResponder = false
                if let state = viewStore.twoFAState, state.isTwoFACodeFieldVisible {
                    isTwoFAFieldFirstResponder = true
                } else {
                    isTwoFAFieldFirstResponder = false
                    viewStore.send(.continueButtonTapped)
                }
            }
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.password)
    }

    private var twoFAField: some View {
        Input(
            text: viewStore.binding(
                get: { $0.twoFAState?.twoFACode ?? "" },
                send: { .twoFA(.didChangeTwoFACode($0)) }
            ),
            isFirstResponder: $isTwoFAFieldFirstResponder,
            label: twoFATitle,
            subText: twoFAErrorMessage,
            subTextStyle: viewStore.twoFAState?.isTwoFACodeIncorrect ?? false ? .error : .default,
            state: (viewStore.twoFAState?.isTwoFACodeIncorrect ?? false || viewStore.isAccountLocked) ? .error : .default,
            isSecure: !isHardwareKeyVisible &&
                viewStore.twoFAState?.twoFAType == .yubiKey ||
                viewStore.twoFAState?.twoFAType == .yubikeyMtGox,
            trailing: {
                if viewStore.twoFAState?.twoFAType == .yubiKey ||
                    viewStore.twoFAState?.twoFAType == .yubikeyMtGox
                {
                    PasswordEyeSymbolButton(isPasswordVisible: $isHardwareKeyVisible)
                } else {
                    EmptyView()
                }
            },
            onReturnTapped: {
                disableAnyFocusedFields()
                viewStore.send(.continueButtonTapped)
            }
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.oneTimeCode)
        .submitLabel(.done)
    }

    private func disableAnyFocusedFields() {
        isWalletIdentifierFirstResponder = false
        isPasswordFieldFirstResponder = false
        isTwoFAFieldFirstResponder = false
    }
}

#if DEBUG
struct PasswordLoginView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialsView(
            context: .none,
            store: Store(
                initialState: .init(),
                reducer: {
                    CredentialsReducer(
                        app: App.preview,
                        mainQueue: .main,
                        sessionTokenService: NoOpSessionTokenService(),
                        deviceVerificationService: NoOpDeviceVerificationService(),
                        emailAuthorizationService: NoOpEmailAuthorizationService(),
                        smsService: NoOpSMSService(),
                        loginService: NoOpLoginService(),
                        errorRecorder: NoOpErrorRecorder(),
                        externalAppOpener: NoOpExternalAppOpener(),
                        analyticsRecorder: NoOpAnalyticsRecorder(),
                        walletRecoveryService: .noop,
                        walletCreationService: .noop,
                        walletFetcherService: .noop,
                        accountRecoveryService: NoOpAccountRecoveryService(),
                        recaptchaService: NoOpGoogleRecatpchaService(),
                        seedPhraseValidator: NoOpValidator(),
                        passwordValidator: PasswordValidator(),
                        signUpCountriesService: NoOpSignupCountryService(),
                        appStoreInformationRepository: NoOpAppStoreInformationRepository()
                    )
                }
            )
        )
    }
}
#endif
