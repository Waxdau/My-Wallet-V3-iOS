// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import ComposableArchitecture
@testable import FeatureAuthenticationDomain
@testable import FeatureAuthenticationUI
import Localization
import ToolKit
@testable import WalletPayloadKit
import XCTest

// Mocks
@testable import AnalyticsKitMock
@testable import FeatureAuthenticationMock
@testable import ToolKitMock

@MainActor final class CredentialsReducerTests: XCTestCase {

    private var mockMainQueue: TestSchedulerOf<DispatchQueue>!
    private var mockPollingQueue: TestSchedulerOf<DispatchQueue>!
    private var reducer: CredentialsReducer!

    private var testStore: TestStore<
        CredentialsState,
        CredentialsAction
    >!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockMainQueue = DispatchQueue.test
        mockPollingQueue = DispatchQueue.test
        reducer = CredentialsReducer(
            app: App.test,
            mainQueue: mockMainQueue.eraseToAnyScheduler(),
            pollingQueue: mockPollingQueue.eraseToAnyScheduler(),
            sessionTokenService: MockSessionTokenService(),
            deviceVerificationService: MockDeviceVerificationService(),
            emailAuthorizationService: MockEmailAuthorizationService(),
            smsService: MockSMSService(),
            loginService: MockLoginService(),
            errorRecorder: NoOpErrorRecorder(),
            externalAppOpener: MockExternalAppOpener(),
            analyticsRecorder: MockAnalyticsRecorder(),
            walletRecoveryService: .mock(),
            walletCreationService: .mock(),
            walletFetcherService: WalletFetcherServiceMock().mock(),
            accountRecoveryService: MockAccountRecoveryService(),
            recaptchaService: MockRecaptchaService(),
            seedPhraseValidator: SeedPhraseValidator(words: Set(WordList.defaultWords)),
            passwordValidator: PasswordValidator(),
            signUpCountriesService: MockSignUpCountriesService(),
            appStoreInformationRepository: NoOpAppStoreInformationRepository()
        )
        testStore = TestStore(
            initialState: .init(),
            reducer: { reducer }
        )
    }

    override func tearDownWithError() throws {
        mockMainQueue = nil
        mockPollingQueue = nil
        testStore = nil
        try super.tearDownWithError()
    }

    func test_verify_initial_state_is_correct() {
        let state = CredentialsState()
        XCTAssertNotNil(state.walletPairingState)
        XCTAssertNotNil(state.passwordState)
        XCTAssertNil(state.twoFAState)
        XCTAssertNil(state.credentialsFailureAlert)
        XCTAssertNil(state.seedPhraseState)
        XCTAssertFalse(state.passwordState.isPasswordIncorrect)
        XCTAssertFalse(state.isManualPairing)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isWalletIdentifierIncorrect)
        XCTAssertFalse(state.isTwoFactorOTPVerified)
        XCTAssertFalse(state.isAccountLocked)
        XCTAssertFalse(state.isTwoFAPrepared)
    }

    func test_did_appear_should_setup_wallet_info() async {
        let mockWalletInfo = MockDeviceVerificationService.mockWalletInfo
        await testStore.send(.didAppear(context: .walletInfo(mockWalletInfo))) { state in
            state.walletPairingState.emailAddress = mockWalletInfo.wallet!.email!
            state.walletPairingState.walletGuid = mockWalletInfo.wallet!.guid
            state.walletPairingState.emailCode = mockWalletInfo.wallet!.emailCode
        }
    }

    func test_did_appear_should_prepare_twoFA_if_needed() async {
        // login service is going to return sms required error
        (reducer.loginService as! MockLoginService).twoFAType = .sms

        let mockWalletInfo = MockDeviceVerificationService.mockWalletInfoWithTwoFA
        await testStore.send(.didAppear(context: .walletInfo(mockWalletInfo))) { state in
            state.walletPairingState.emailAddress = mockWalletInfo.wallet!.email!
            state.walletPairingState.walletGuid = mockWalletInfo.wallet!.guid
            state.walletPairingState.emailCode = mockWalletInfo.wallet!.emailCode
            state.isTwoFAPrepared = true
        }

        await testStore.receive(.walletPairing(.authenticate("", autoTrigger: true))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()

        // authentication with sms requied
        await testStore.receive(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.sms)))) { state in
            state.twoFAState = .init(
                twoFAType: .sms
            )
        }
        await testStore.receive(.walletPairing(.handleSMS))
        await testStore.receive(.twoFA(.showResendSMSButton(true))) { state in
            state.twoFAState?.isResendSMSButtonVisible = true
        }
        await testStore.receive(.twoFA(.showTwoFACodeField(true))) { state in
            state.twoFAState?.isTwoFACodeFieldVisible = true
            state.isLoading = false
        }
        await testStore.receive(
            .alert(
                .presented(
                    .show(
                        title: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.title,
                        message: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.message
                    )
                )
            )
        ) { state in
            state.credentialsFailureAlert = AlertState(
                title: TextState(
                    verbatim: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.title
                ),
                message: TextState(
                    verbatim: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.message
                ),
                dismissButton: .default(
                    TextState(LocalizationConstants.okString),
                    action: .send(.dismiss)
                )
            )
        }
        await mockMainQueue.advance()
    }

    func test_wallet_identifier_fallback_did_appear_should_setup_guid_if_present() async {
        let mockWalletGuid = MockDeviceVerificationService.mockWalletInfo.wallet!.guid
        await testStore.send(.didAppear(context: .walletIdentifier(guid: mockWalletGuid))) { state in
            state.walletPairingState.walletGuid = mockWalletGuid
        }
    }

    func test_manual_screen_did_appear_should_setup_session_token() async {
        await testStore.send(.didAppear(context: .manualPairing)) { state in
            state.walletPairingState.emailAddress = ""
            state.isManualPairing = true
        }
        await testStore.receive(.walletPairing(.setupSessionToken))
        await mockMainQueue.advance()
        await testStore.receive(.walletPairing(.didSetupSessionToken(.success(.noValue))))
    }

    // MARK: - Wallet Pairing Actions

    func test_authenticate_success_should_update_view_state_and_decrypt_password() async {
        /*
         Use Case: Authentication flow without any 2FA
         1. Setup walletInfo
         2. Reset error states (account locked or password error, for any previous errors)
         3. Decrypt wallet with the password from user
         */

        // some preliminery actions
        await setupWalletInfo()

        // authentication without 2FA
        await testStore.send(.walletPairing(.authenticate(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()
        await testStore.receive(.walletPairing(.decryptWalletWithPassword("")))
    }

    func test_authenticate_email_required_should_return_relevant_actions() async {
        /*
         Use Case: Authentication flow with auto-authorized email approval
         1. Setup walletInfo
         2. Reset error states (account locked or password error, for any previous errors)
         3. When authenticate request sent, received an error saying email authorization required
         4. Auto-approve email authorization, the 2FA type will be set to standard
         5. Conduct polling every 2 seconds, check if GUID has been set remotely
         6. Authenticate again, clear error states again, and proceed to wallet decryption with pw
         */

        // set email authorization as default twoFA type
        (reducer.loginService as! MockLoginService).twoFAType = .email

        // some preliminery actions
        await setupWalletInfo()

        // authentication
        await testStore.send(.walletPairing(.authenticate(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()

        // authentication with email required
        await testStore.receive(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.email))))
        await testStore.receive(.walletPairing(.approveEmailAuthorization))
        await testStore.receive(.walletPairing(.startPolling))
        await mockMainQueue.advance()

        // after approval twoFA type should be set to standard
        (reducer.loginService as! MockLoginService).twoFAType = .standard

        // nothing should happen after 1 second
        await mockPollingQueue.advance(by: 1)

        // polling should happen after 1 more second (2 seconds in total)
        await mockPollingQueue.advance(by: 1)

        await mockMainQueue.advance()
        await testStore.receive(.walletPairing(.pollWalletIdentifier))
        await testStore.receive(.walletPairing(.authenticate("")))
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await testStore.receive(.walletPairing(.decryptWalletWithPassword("")))
        await mockMainQueue.advance()
    }

    func test_authenticate_sms_required_should_return_relevant_actions() async {
        /*
         Use Case: Authentication flow with SMS as 2FA
         1. Setup walletInfo
         2. Reset error states (account locked or password error, for any previous errors)
         3. When authenticate request sent, received an error saying SMS required
         4. Request an SMS code for user
         5. Show the resend SMS button and 2FA field
         */

        // set sms as default twoFA type
        (reducer.loginService as! MockLoginService).twoFAType = .sms

        // some preliminery actions
        await setupWalletInfo()

        // authentication
        await testStore.send(.walletPairing(.authenticate(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()

        // authentication with sms requied
        await testStore.receive(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.sms)))) { state in
            state.twoFAState = .init(
                twoFAType: .sms
            )
        }
        await testStore.receive(.walletPairing(.handleSMS))
        await testStore.receive(.twoFA(.showResendSMSButton(true))) { state in
            state.twoFAState?.isResendSMSButtonVisible = true
        }
        await testStore.receive(.twoFA(.showTwoFACodeField(true))) { state in
            state.twoFAState?.isTwoFACodeFieldVisible = true
            state.isLoading = false
        }
        await testStore.receive(
            .alert(
                .presented(
                    .show(
                        title: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.title,
                        message: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.message
                    )
                )
            )
        ) { state in
            state.credentialsFailureAlert = AlertState(
                title: TextState(
                    verbatim: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.title
                ),
                message: TextState(
                    verbatim: LocalizationConstants.FeatureAuthentication.EmailLogin.Alerts.SMSCode.Success.message
                ),
                dismissButton: .default(
                    TextState(LocalizationConstants.okString),
                    action: .send(.dismiss)
                )
            )
        }
        await mockMainQueue.advance()
    }

    func test_authenticate_google_auth_required_should_return_relevant_actions() async {
        /*
         Use Case: Authentication flow with google authenticator as 2FA
         1. Setup walletInfo
         2. Reset error states (account locked or password error, for any previous errors)
         3. When authenticate request sent, received an error saying google authenticator required
         4. Show the 2FA Field
         */

        // set google auth as default twoFA type
        (reducer.loginService as! MockLoginService).twoFAType = .google

        // some preliminery actions
        await setupWalletInfo()

        // authentication
        await testStore.send(.walletPairing(.authenticate(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()

        // authentication with google auth required
        await testStore.receive(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.google)))) { state in
            state.twoFAState = .init(
                twoFAType: .google
            )
        }
        await testStore.receive(.twoFA(.showTwoFACodeField(true))) { state in
            state.twoFAState?.isTwoFACodeFieldVisible = true
            state.isLoading = false
        }
    }

    func test_authenticate_with_twoFA_should_return_relevant_actions() async {
        /*
         Use Case: Authentication flow with google auth as 2FA
         1. Authenticate with 2FA, clear 2FA error states
         2. Set 2FA verified on success
         3. Proceed to wallet decryption with password
         */

        // set 2FA required (e.g. sms) and initialise twoFA state
        (reducer.loginService as! MockLoginService).twoFAType = .google
        // some preliminery actions
        await setupWalletInfo()

        // authentication using 2FA
        await testStore.send(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.google)))) { state in
            state.twoFAState = .init(
                twoFAType: .google
            )
        }
        await testStore.receive(.twoFA(.showTwoFACodeField(true))) { state in
            state.twoFAState?.isTwoFACodeFieldVisible = true
        }
        await testStore.send(.walletPairing(.authenticateWithTwoFactorOTP(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.twoFA(.showIncorrectTwoFACodeError(.none)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()
        await testStore.receive(.walletPairing(.twoFactorOTPDidVerified)) { state in
            state.isTwoFactorOTPVerified = true
            state.isLoading = false
        }
        await testStore.receive(.walletPairing(.decryptWalletWithPassword(""))) { state in
            state.isLoading = true
        }
    }

    func test_authenticate_with_twoFA_wrong_code_error() async {
        // set 2FA required (e.g. google)
        (reducer.loginService as! MockLoginService).twoFAType = .google

        // set 2FA error type
        let mockAttemptsLeft = 4
        (reducer.loginService as! MockLoginService)
            .twoFAServiceError = .twoFAWalletServiceError(.wrongCode(attemptsLeft: mockAttemptsLeft))

        // some preliminery actions
        await setupWalletInfo()

        // authentication using 2FA
        await testStore.send(.walletPairing(.authenticateDidFail(.twoFactorOTPRequired(.google)))) { state in
            state.twoFAState = TwoFAState(
                twoFACode: "",
                twoFAType: .google,
                isTwoFACodeFieldVisible: false,
                isResendSMSButtonVisible: false,
                isTwoFACodeIncorrect: false,
                twoFACodeIncorrectContext: .none,
                twoFACodeAttemptsLeft: 5
            )
        }
        await testStore.receive(.twoFA(.showTwoFACodeField(true))) { state in
            state.twoFAState?.isTwoFACodeFieldVisible = true
        }
        await testStore.send(.walletPairing(.authenticateWithTwoFactorOTP(""))) { state in
            state.isLoading = true
        }
        await testStore.receive(.showAccountLockedError(false))
        await testStore.receive(.password(.showIncorrectPasswordError(false)))
        await testStore.receive(.twoFA(.showIncorrectTwoFACodeError(.none)))
        await testStore.receive(.alert(.dismiss))
        await mockMainQueue.advance()
        await testStore.receive(
            .walletPairing(
                .authenticateWithTwoFactorOTPDidFail(
                    .twoFAWalletServiceError(
                        .wrongCode(attemptsLeft: mockAttemptsLeft)
                    )
                )
            )
        )
        await testStore.receive(.twoFA(.didChangeTwoFACodeAttemptsLeft(mockAttemptsLeft))) { state in
            state.twoFAState?.twoFACodeAttemptsLeft = mockAttemptsLeft
        }
        await testStore.receive(.twoFA(.showIncorrectTwoFACodeError(.incorrect))) { state in
            state.twoFAState?.twoFACodeIncorrectContext = .incorrect
            state.twoFAState?.isTwoFACodeIncorrect = true
            state.isLoading = false
        }
    }

    // MARK: - Helpers

    private func setupWalletInfo() async {
        let mockWalletInfo = MockDeviceVerificationService.mockWalletInfo
        await testStore.send(.didAppear(context: .walletInfo(mockWalletInfo))) { state in
            state.walletPairingState.emailAddress = mockWalletInfo.wallet!.email!
            state.walletPairingState.walletGuid = mockWalletInfo.wallet!.guid
            state.walletPairingState.emailCode = mockWalletInfo.wallet!.emailCode
        }
    }
}
