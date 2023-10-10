// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import BlockchainNamespace
import Combine
import ComposableArchitecture
import ComposableNavigation
import FeatureAuthenticationDomain
import Localization
import SwiftUI
import ToolKit
import UIComponentsKit
import WalletPayloadKit

public enum CreateAccountStepOneRoute: NavigationRoute {
    private typealias LocalizedStrings = LocalizationConstants.Authentication.CountryAndStatePickers

    case countryPicker
    case statePicker
    case createWalletStepTwo

    @MainActor
    @ViewBuilder
    public func destination(in store: Store<CreateAccountStepOneState, CreateAccountStepOneAction>) -> some View {
        switch self {
        case .countryPicker:
            WithViewStore(store, observe: { $0 }) { viewStore in
                ModalContainer(
                    title: LocalizedStrings.countriesPickerTitle,
                    subtitle: LocalizedStrings.countriesPickerSubtitle,
                    onClose: { viewStore.send(.set(\.$selectedAddressSegmentPicker, nil)) },
                    content: {
                        CountryPickerView(
                            selectedItem: viewStore.$country,
                            items: viewStore.$countries
                        )
                    }
                )
            }

        case .statePicker:
            WithViewStore(store, observe: { $0 }) { viewStore in
                ModalContainer(
                    title: LocalizedStrings.statesPickerTitle,
                    subtitle: LocalizedStrings.statesPickerSubtitle,
                    onClose: { viewStore.send(.set(\.$selectedAddressSegmentPicker, nil)) },
                    content: {
                        StatePickerView(selectedItem: viewStore.$countryState)
                    }
                )
            }

        case .createWalletStepTwo:
            IfLetStore(
                store.scope(
                    state: \.createWalletStateStepTwo,
                    action: CreateAccountStepOneAction.createWalletStepTwo
                ),
                then: CreateAccountViewStepTwo.init(store:)
            )
        }
    }
}

public struct CreateAccountStepOneState: Equatable, NavigationState {

    public enum InputValidationError: Equatable {
        case noCountrySelected
        case noCountryStateSelected
        case invalidReferralCode
    }

    public enum InputValidationState: Equatable {
        case unknown
        case valid
        case invalid(InputValidationError)

        var isInvalid: Bool {
            switch self {
            case .invalid:
                return true
            case .valid, .unknown:
                return false
            }
        }
    }

    public enum Field: Equatable {
        case email
        case password
        case referralCode
    }

    enum AddressSegmentPicker: Hashable {
        case country
        case countryState
    }

    public var route: RouteIntent<CreateAccountStepOneRoute>?
    public var createWalletStateStepTwo: CreateAccountStepTwoState?

    public var context: CreateAccountContextStepTwo

    // User Input
    @BindingState public var referralCode: String
    @BindingState public var country: SearchableItem<String>?
    @BindingState public var countryState: SearchableItem<String>?

    @BindingState public var countries: [SearchableItem<String>]

    // Form interaction
    @BindingState public var passwordFieldTextVisible: Bool = false
    @BindingState public var selectedInputField: Field?
    @BindingState var selectedAddressSegmentPicker: AddressSegmentPicker?

    // Validation
    public var validatingInput: Bool = false
    public var inputValidationState: InputValidationState
    public var referralCodeValidationState: InputValidationState
    @PresentationState public var failureAlert: AlertState<CreateAccountStepOneAction.AlertAction>?

    public var isCreatingWallet = false
    public var isGoingToNextStep = false

    var isNextStepButtonDisabled: Bool {
        validatingInput
        || inputValidationState.isInvalid
        || isCreatingWallet
        || referralCodeValidationState.isInvalid
        || country == nil
        || shouldDisplayCountryStateField && countryState == nil
    }

    var shouldDisplayCountryStateField: Bool {
        country?.id.lowercased() == "us"
    }

    public init(
        context: CreateAccountContextStepTwo,
        countries: [SearchableItem<String>] = CountryPickerView.countries,
        states: [SearchableItem<String>] = StatePickerView.usaStates
    ) {
        self.context = context
        self.countries = countries
        self.referralCode = ""
        self.inputValidationState = .unknown
        self.referralCodeValidationState = .unknown
    }
}

public enum CreateAccountStepOneAction: Equatable, NavigationAction, BindableAction {

    public enum AlertAction: Equatable {
        case show(title: String, message: String)
        case dismiss
    }

    case onAppear
    case alert(PresentationAction<AlertAction>)
    case binding(BindingAction<CreateAccountStepOneState>)
    // use `createAccount` to perform the account creation. this action is fired after the user confirms the details and the input is validated.
    case goToStepTwo
    case nextStepButtonTapped
    case createWalletStepTwo(CreateAccountStepTwoAction)
    case importAccount(_ mnemonic: String)
    case didValidateAfterFormSubmission
    case didUpdateInputValidation(CreateAccountStepOneState.InputValidationState)
    case didUpdateReferralValidation(CreateAccountStepOneState.InputValidationState)
    case validateReferralCode
    case onWillDisappear
    case accountCreationCancelled
    case route(RouteIntent<CreateAccountStepOneRoute>?)
    case accountRecoveryFailed(WalletRecoveryError)
    case signUpCountriesFetched([Country])
    case accountCreation(Result<WalletCreatedContext, WalletCreationServiceError>)
    case accountImported(Result<Either<WalletCreatedContext, EmptyValue>, WalletCreationServiceError>)
    case walletFetched(Result<Either<EmptyValue, WalletFetchedContext>, WalletFetcherServiceError>)
    case informWalletFetched(WalletFetchedContext)
    // required for legacy flow
    case triggerAuthenticate
    case none
}

typealias CreateAccountStepOneLocalization = LocalizationConstants.FeatureAuthentication.CreateAccount

struct CreateAccountStepOneReducer: Reducer {
    typealias State = CreateAccountStepOneState
    typealias Action = CreateAccountStepOneAction

    let mainQueue: AnySchedulerOf<DispatchQueue>
    let passwordValidator: PasswordValidatorAPI
    let externalAppOpener: ExternalAppOpener
    let analyticsRecorder: AnalyticsEventRecorderAPI
    let walletRecoveryService: WalletRecoveryService
    let walletCreationService: WalletCreationService
    let walletFetcherService: WalletFetcherService
    let signUpCountriesService: SignUpCountriesServiceAPI
    let checkReferralClient: CheckReferralClientAPI?
    let recaptchaService: GoogleRecaptchaServiceAPI
    let app: AppProtocol?

    init(
        mainQueue: AnySchedulerOf<DispatchQueue>,
        passwordValidator: PasswordValidatorAPI,
        externalAppOpener: ExternalAppOpener,
        analyticsRecorder: AnalyticsEventRecorderAPI,
        walletRecoveryService: WalletRecoveryService,
        walletCreationService: WalletCreationService,
        walletFetcherService: WalletFetcherService,
        signUpCountriesService: SignUpCountriesServiceAPI,
        recaptchaService: GoogleRecaptchaServiceAPI,
        checkReferralClient: CheckReferralClientAPI? = nil,
        app: AppProtocol
    ) {
        self.mainQueue = mainQueue
        self.passwordValidator = passwordValidator
        self.externalAppOpener = externalAppOpener
        self.analyticsRecorder = analyticsRecorder
        self.walletRecoveryService = walletRecoveryService
        self.walletCreationService = walletCreationService
        self.walletFetcherService = walletFetcherService
        self.signUpCountriesService = signUpCountriesService
        self.checkReferralClient = checkReferralClient
        self.recaptchaService = recaptchaService
        self.app = app
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.$referralCode):
                return Effect.send(.validateReferralCode)

            case .binding(\.$country):
                return .merge(
                    Effect.send(.didUpdateInputValidation(.unknown)),
                    Effect.send(.set(\.$selectedAddressSegmentPicker, nil))
                )

            case .binding(\.$countryState):
                return .merge(
                    Effect.send(.didUpdateInputValidation(.unknown)),
                    Effect.send(.set(\.$selectedAddressSegmentPicker, nil))
                )

            case .binding(\.$selectedAddressSegmentPicker):
                guard let selection = state.selectedAddressSegmentPicker else {
                    return Effect.send(.dismiss())
                }
                state.selectedInputField = nil
                switch selection {
                case .country:
                    return .enter(into: .countryPicker, context: .none)
                case .countryState:
                    return .enter(into: .statePicker, context: .none)
                }

            case .goToStepTwo:
                guard state.inputValidationState == .valid else {
                    return .none
                }
                let country = state.country?.id
                let countryState = state.countryState?.id
                return .merge(
                    .run { _ in
                        app?.state.transaction { state in
                            state.set(blockchain.ux.user.authentication.sign.up.address.country.code, to: country ?? "N/A")
                            if let countryState {
                                state.set(blockchain.ux.user.authentication.sign.up.address.country.state, to: countryState)
                            } else {
                                state.clear(blockchain.ux.user.authentication.sign.up.address.country.state)
                            }
                        }
                    },
                    Effect.send(.navigate(to: .createWalletStepTwo))
                )

            case .validateReferralCode:
                return .publisher { [referralCode = state.referralCode] in
                    validateReferralInput(code: referralCode)
                        .map(CreateAccountStepOneAction.didUpdateReferralValidation)
                        .receive(on: mainQueue)
                }

            case .nextStepButtonTapped:
                state.isGoingToNextStep = true
                state.validatingInput = true
                state.selectedInputField = nil

                return .concatenate(
                    .publisher { [state] in
                        validateInputs(state: state)
                            .map(CreateAccountStepOneAction.didUpdateInputValidation)
                            .receive(on: mainQueue)
                    },

                    .publisher { [state] in
                        checkReferralCode(state.referralCode)
                            .map(CreateAccountStepOneAction.didUpdateReferralValidation)
                            .receive(on: mainQueue)
                    },

                    Effect.send(.didValidateAfterFormSubmission)
                )

            case .didValidateAfterFormSubmission:
                guard !state.inputValidationState.isInvalid,
                      !state.referralCodeValidationState.isInvalid
                else {
                    return .none
                }

                return Effect.send(.goToStepTwo)

            case .didUpdateInputValidation(let validationState):
                state.validatingInput = false
                state.inputValidationState = validationState
                return .none

            case .didUpdateReferralValidation(let validationState):
                state.referralCodeValidationState = validationState
                return .none

            case .onWillDisappear:
                if !state.isGoingToNextStep {
                    return Effect.send(.accountCreationCancelled)
                } else {
                    state.isGoingToNextStep = false
                    return .none
                }

            case .route(let route):
                guard let routeValue = route?.route else {
                    state.createWalletStateStepTwo = nil
                    state.route = route
                    return .none
                }
                switch routeValue {
                case .createWalletStepTwo:
                    guard let country = state.country else {
                        fatalError("Country is nil must never happen")
                    }
                    state.createWalletStateStepTwo = .init(
                        context: .createWallet,
                        country: country,
                        countryState: state.countryState,
                        referralCode: state.referralCode
                    )
                case .countryPicker:
                    break
                case .statePicker:
                    break
                }
                state.route = route
                return .none

            case .accountRecoveryFailed(let error):
                let title = LocalizationConstants.Errors.error
                let message = error.localizedDescription
                return Effect.send(.alert(.presented(.show(title: title, message: message))))

            case .alert(.presented(.show(let title, let message))):
                state.failureAlert = AlertState(
                    title: TextState(verbatim: title),
                    message: TextState(verbatim: message),
                    dismissButton: .default(
                        TextState(LocalizationConstants.okString),
                        action: .send(.dismiss)
                    )
                )
                return .none

            case .createWalletStepTwo(.triggerAuthenticate):
                return Effect.send(.triggerAuthenticate)

            case .createWalletStepTwo(.importAccount(let mnemonic)):
                return Effect.send(.importAccount(mnemonic))

            case .createWalletStepTwo(.walletFetched(let result)):
                return Effect.send(.walletFetched(result))

            case .createWalletStepTwo(.informWalletFetched(let context)):
                return Effect.send(.informWalletFetched(context))

            case .createWalletStepTwo(.accountCreation(.failure(let error))):
                return .run { _ in
                    app?.post(
                        event: blockchain.ux.user.authentication.sign.up.did.fail,
                        context: [
                            blockchain.ux.user.authentication.sign.up.did.fail.error: String(describing: error)
                        ]
                    )
                }

            case .createWalletStepTwo(.createButtonTapped):
                return .run { _ in
                    app?.post(event: blockchain.ux.user.authentication.sign.up.create.tap)
                }

            case .createWalletStepTwo(.accountCreation(.success)):
                return .run { _ in
                    app?.post(event: blockchain.ux.user.authentication.sign.up.did.succeed)
                }

            case .alert(.dismiss), .alert(.presented(.dismiss)):
                state.failureAlert = nil
                return .none

            case .triggerAuthenticate:
                return .none

            case .none:
                return .none

            case .binding:
                return .none

            case .onAppear:
                return .merge(
                    .run { _ in
                        app?.post(event: blockchain.ux.user.authentication.sign.up)
                    },
                    .publisher {
                        signUpCountriesService
                            .countries
                            .replaceError(with: [])
                            .map(CreateAccountStepOneAction.signUpCountriesFetched)
                            .receive(on: mainQueue)
                    }
                )

            case .signUpCountriesFetched(let countries):
                if countries.isNotEmpty {
                    state.countries = countries
                        .compactMap { country -> SearchableItem? in
                            guard let countryName = Locale.current.localizedString(
                                forRegionCode: country.code
                            ) else { return nil }
                            return SearchableItem(
                                id: country.code,
                                title: countryName
                            )
                        }
                        .sorted {
                            $0.title.localizedCompare($1.title) == .orderedAscending
                        }
                }
                return .none

            case .informWalletFetched:
                return .none

            case .accountCreation,
                    .accountImported:
                return .none

            case .createWalletStepTwo:
                return .none

            case .importAccount:
                return .none

            case .walletFetched:
                return .none

            case .accountCreationCancelled:
                if case .importWallet = state.context {
                    analyticsRecorder.record(
                        event: .importWalletCancelled
                    )
                }
                return .none
            }
        }
        .ifLet(\.createWalletStateStepTwo, action: /Action.createWalletStepTwo) {
            CreateAccountStepTwoReducer(
                mainQueue: mainQueue,
                passwordValidator: passwordValidator,
                externalAppOpener: externalAppOpener,
                analyticsRecorder: analyticsRecorder,
                walletRecoveryService: walletRecoveryService,
                walletCreationService: walletCreationService,
                walletFetcherService: walletFetcherService,
                recaptchaService: recaptchaService,
                app: app
            )
        }
    }
}

extension CreateAccountStepOneReducer {

    fileprivate func validateInputs(
        state: CreateAccountStepOneState
    ) -> AnyPublisher<CreateAccountStepOneState.InputValidationState, Never> {
        let hasValidCountry = state.country != nil
        let hasValidCountryState = state.countryState != nil || !state.shouldDisplayCountryStateField

        guard hasValidCountry else {
            return .just(.invalid(.noCountrySelected))
        }
        guard hasValidCountryState else {
            return .just(.invalid(.noCountryStateSelected))
        }
        return .just(.valid)
    }

    fileprivate func validateReferralInput(
        code: String
    ) -> AnyPublisher<CreateAccountStepOneState.InputValidationState, Never> {
        guard code.range(
            of: TextRegex.noSpecialCharacters.rawValue,
            options: .regularExpression
        ) != nil else { return .just(.invalid(.invalidReferralCode)) }

        return .just(.unknown)
    }

    fileprivate func checkReferralCode(_
        code: String
    ) -> AnyPublisher<CreateAccountStepOneState.InputValidationState, Never> {
        guard code.isNotEmpty, let client = checkReferralClient else { return .just(.unknown) }
        return client
            .checkReferral(with: code)
            .map { _ in
                CreateAccountStepOneState.InputValidationState.valid
            }
            .catch { _ -> AnyPublisher<CreateAccountStepOneState.InputValidationState, Never> in
                .just(.invalid(.invalidReferralCode))
            }
            .eraseToAnyPublisher()
    }

    func saveReferral(with code: String) -> Effect<Void> {
        if code.isNotEmpty {
            app?.post(value: code, of: blockchain.user.creation.referral.code)
        }
        return .none
    }
}
