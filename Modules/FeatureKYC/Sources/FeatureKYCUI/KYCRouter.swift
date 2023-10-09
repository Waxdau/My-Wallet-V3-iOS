// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import BlockchainNamespace
import Combine
import DIKit
import Errors
import FeatureFormDomain
import FeatureKYCDomain
import Localization
import NetworkKit
import PlatformKit
import PlatformUIKit
import RxRelay
import RxSwift
import ToolKit
import UIComponentsKit
import UIKit

enum KYCEvent {

    /// When a particular screen appears, we need to
    /// look at the `NabuUser` object and determine if
    /// there is data there for pre-populate the screen with.
    case pageWillAppear(KYCPageType)

    /// This will push on the next page in the KYC flow.
    case nextPageFromPageType(KYCPageType, KYCPagePayload?)

    /// Event emitted when the provided page type emits an error
    case failurePageForPageType(KYCPageType, KYCPageError)
}

protocol KYCRouterDelegate: AnyObject {
    func apply(model: KYCPageModel)
}

public enum UserAddressSearchResult {
    case abandoned
    case saved
}

public protocol AddressSearchFlowPresenterAPI {
    func openSearchAddressFlow(
        country: String,
        state: String?
    ) -> AnyPublisher<UserAddressSearchResult, Never>
}

/// Coordinates the KYC flow. This component can be used to start a new KYC flow, or if
/// the user drops off mid-KYC and decides to continue through it again, the coordinator
/// will handle recovering where they left off.
final class KYCRouter: KYCRouterAPI {

    // MARK: - Public Properties

    weak var delegate: KYCRouterDelegate?

    // MARK: - Private Properties

    private(set) var user: NabuUser?

    private(set) var country: CountryData?

    private(set) var states: [KYCState] = []

    private var pager: KYCPagerAPI!

    private weak var rootViewController: UIViewController?

    private var navController: KYCOnboardingNavigationController?

    private let disposables = CompositeDisposable()

    private let disposeBag = DisposeBag()

    private let pageFactory = KYCPageViewFactory()

    private let loadingViewPresenter: LoadingViewPresenting

    private let app: AppProtocol
    private var userTiersResponse: KYC.UserTiers?
    private var kycSettings: KYCSettingsAPI

    private let tiersService: KYCTiersServiceAPI
    private let networkAdapter: NetworkAdapterAPI
    private let analyticsRecorder: AnalyticsEventRecorderAPI
    private let nabuUserService: NabuUserServiceAPI
    private let requestBuilder: RequestBuilder
    private let emailVerificationService: FeatureKYCDomain.EmailVerificationServiceAPI
    private let externalAppOpener: ExternalAppOpener

    private let webViewServiceAPI: WebViewServiceAPI

    private let kycStoppedRelay = PublishRelay<Void>()
    private let kycFinishedRelay = PublishRelay<KYC.Tier>()

    private var parentFlow: KYCParentFlow?

    private var errorRecorder: ErrorRecording
    private var alertPresenter: AlertViewPresenterAPI

    private var addressSearchFlowPresenter: AddressSearchFlowPresenterAPI

    /// KYC finsihed with `verified` in-progress / approved
    var verifiedFinished: Observable<Void> {
        kycFinishedRelay
            .filter { $0 == .verified }
            .mapToVoid()
    }

    var kycFinished: Observable<KYC.Tier> {
        kycFinishedRelay.asObservable()
    }

    var kycStopped: Observable<Void> {
        kycStoppedRelay.asObservable()
    }

    private var bag = Set<AnyCancellable>()

    init(
        app: AppProtocol = resolve(),
        requestBuilder: RequestBuilder = resolve(tag: DIKitContext.retail),
        webViewServiceAPI: WebViewServiceAPI = resolve(),
        tiersService: KYCTiersServiceAPI = resolve(),
        analyticsRecorder: AnalyticsEventRecorderAPI = resolve(),
        errorRecorder: ErrorRecording = resolve(),
        alertPresenter: AlertViewPresenterAPI = resolve(),
        addressSearchFlowPresenter: AddressSearchFlowPresenterAPI = resolve(),
        nabuUserService: NabuUserServiceAPI = resolve(),
        emailVerificationService: FeatureKYCDomain.EmailVerificationServiceAPI = resolve(),
        externalAppOpener: ExternalAppOpener = resolve(),
        kycSettings: KYCSettingsAPI = resolve(),
        loadingViewPresenter: LoadingViewPresenting = resolve(),
        networkAdapter: NetworkAdapterAPI = resolve(tag: DIKitContext.retail)
    ) {
        self.app = app
        self.requestBuilder = requestBuilder
        self.errorRecorder = errorRecorder
        self.alertPresenter = alertPresenter
        self.addressSearchFlowPresenter = addressSearchFlowPresenter
        self.analyticsRecorder = analyticsRecorder
        self.nabuUserService = nabuUserService
        self.emailVerificationService = emailVerificationService
        self.externalAppOpener = externalAppOpener
        self.webViewServiceAPI = webViewServiceAPI
        self.tiersService = tiersService
        self.kycSettings = kycSettings
        self.loadingViewPresenter = loadingViewPresenter
        self.networkAdapter = networkAdapter
    }

    deinit {
        disposables.dispose()
    }

    // MARK: Public

    func start(parentFlow: KYCParentFlow) {
        start(tier: .verified, parentFlow: parentFlow, from: nil)
    }

    func start(tier: KYC.Tier, parentFlow: KYCParentFlow) {
        start(tier: tier, parentFlow: parentFlow, from: nil)
    }

    func start(
        tier: KYC.Tier,
        parentFlow: KYCParentFlow,
        from viewController: UIViewController?
    ) {
        self.parentFlow = parentFlow
        guard let viewController = viewController ?? UIApplication.shared.topMostViewController else {
            Logger.shared.warning("Cannot start KYC. rootViewController is nil.")
            return
        }
        rootViewController = viewController

        app.post(
            event: blockchain.ux.kyc.event.did.start,
            context: [
                blockchain.ux.kyc.tier: {
                    switch tier {
                    case .unverified:
                        return blockchain.ux.kyc.tier.none[]
                    case .verified:
                        return blockchain.ux.kyc.tier.gold[]
                    }
                }()
            ]
        )

        switch tier {
        case .unverified:
            analyticsRecorder.record(event: AnalyticsEvents.KYC.kycUnverifiedStart)
        case .verified:
            analyticsRecorder.record(event: AnalyticsEvents.KYC.kycVerifiedStart)
            analyticsRecorder.record(
                event: AnalyticsEvents.New.Onboarding.upgradeVerificationClicked(
                    origin: .init(parentFlow),
                    tier: tier.rawValue
                )
            )
        }

        let postTierObservable = post(tier: tier).asObservable()

        let disposable = Observable
            .zip(
                nabuUserService.fetchUser().asObservable(),
                postTierObservable,
                app.publisher(for: blockchain.ux.kyc.SSN.should.be.collected, as: Bool.self)
                    .replaceError(with: false)
                    .prefix(1)
                    .asObservable()
            )
            .subscribe(on: MainScheduler.asyncInstance)
            .observe(on: MainScheduler.instance)
            .hideLoaderOnDisposal(loader: loadingViewPresenter)
            .subscribe(onNext: { [weak self] user, tiersResponse, isSSNRequired in
                self?.isNewProfileEnabled { isNewProfileEnabled in
                    self?.pager = KYCPager(isNewProfile: isNewProfileEnabled, tier: tier, tiersResponse: tiersResponse)
                    Logger.shared.debug("Got user with ID: \(user.personalDetails.identifier ?? "")")
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.userTiersResponse = tiersResponse
                    strongSelf.user = user

                    let startingPage = KYCPageType.startingPage(
                        forUser: user,
                        requiredTier: tier,
                        tiersResponse: tiersResponse,
                        hasQuestions: strongSelf.hasQuestions,
                        isNewProfile: isNewProfileEnabled,
                        isSSNRequired: isSSNRequired
                    )

                    if startingPage == .finish {
                        return strongSelf.finish()
                    }

                    if startingPage != .accountStatus {
                        /// If the starting page is accountStatus, they do not have any additional
                        /// pages to view, so we don't want to set `isCompletingKyc` to `true`.
                        strongSelf.kycSettings.isCompletingKyc = true
                    }

                    strongSelf.initializeNavigationStack(
                        viewController,
                        user: user,
                        tier: tier,
                        isNewProfile: isNewProfileEnabled,
                        isSSNRequired: isSSNRequired
                    )
                    strongSelf.restoreToMostRecentPageIfNeeded(
                        tier: tier,
                        isNewProfile: isNewProfileEnabled,
                        isSSNRequired: isSSNRequired
                    )
                }
            }, onError: { [alertPresenter, errorRecorder] error in
                Logger.shared.error("Failed to get user: \(String(describing: error))")
                errorRecorder.error(error)
                alertPresenter.notify(
                    content: .init(
                        title: LocalizationConstants.KYC.Errors.cannotFetchUserAlertTitle,
                        message: String(describing: error)
                    ),
                    in: viewController
                )
            })
        disposables.insertWithDiscardableResult(disposable)
    }

    // Called when the entire KYC process has been completed.
    func finish() {
        dismiss { [app, tiersService, kycFinishedRelay, disposeBag] in
            tiersService.fetchTiers()
                .asObservable()
                .map(\.latestApprovedTier)
                .catchAndReturn(.unverified)
                .bindAndCatch(to: kycFinishedRelay)
                .disposed(by: disposeBag)
            NotificationCenter.default.post(
                name: Constants.NotificationKeys.kycFinished,
                object: nil
            )
            NotificationCenter.default.post(name: .kycStatusChanged, object: nil)
            NotificationCenter.default.post(name: .kycFinished, object: nil)
            app.post(event: blockchain.ux.kyc.event.did.finish)
            app.post(event: blockchain.ux.kyc.event.status.did.change)
        }
    }

    // Called when the KYC process is stopped before completing.
    func stop() {
        dismiss { [app, kycStoppedRelay] in
            kycStoppedRelay.accept(())
            NotificationCenter.default.post(
                name: Constants.NotificationKeys.kycStopped,
                object: nil
            )
            NotificationCenter.default.post(name: .kycStatusChanged, object: nil)
            app.post(event: blockchain.ux.kyc.event.did.stop)
            app.post(event: blockchain.ux.kyc.event.status.did.change)
        }
    }

    private func dismiss(completion: @escaping () -> Void) {
        guard let navController else {
            completion()
            return
        }
        navController.dismiss(animated: true, completion: completion)
    }

    func handle(event: KYCEvent) {
        switch event {
        case .pageWillAppear(let type):
            handlePageWillAppear(for: type)
            app.post(
                value: type.tag[],
                of: blockchain.ux.kyc.current.state
            )
            app.post(
                event: blockchain.ux.kyc.event.did.enter.state[][type.descendant]!,
                context: [blockchain.ux.kyc.current.state: type.tag[]]
            )
        case .failurePageForPageType(let type, let error):
            handleFailurePage(for: error)
            app.post(
                event: blockchain.ux.kyc.event.did.fail.on.state[][type.descendant]!,
                context: [blockchain.ux.kyc.current.state: type.tag[]]
            )
        case .nextPageFromPageType(let type, let payload):
            handlePayloadFromPageType(type, payload)
            app.post(
                event: blockchain.ux.kyc.event.did.confirm.state[][type.descendant]!,
                context: [blockchain.ux.kyc.current.state: type.tag[]]
            )
            let disposable = pager.nextPage(from: type, payload: payload)
                .subscribe(on: MainScheduler.asyncInstance)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] nextPage in
                    guard let self else {
                        return
                    }

                    let controller = pageFactory.createFrom(
                        pageType: nextPage,
                        in: self,
                        payload: payload
                    )

                    checkConfigurations(
                        page: nextPage,
                        user: user
                    ) { shouldShowEmailVerification, shouldShowAddressFlow in
                        if let informationController = controller as? KYCInformationController, nextPage == .accountStatus {
                            self.presentInformationController(informationController)
                        } else if shouldShowEmailVerification {
                            if let navController = self.navController {
                                navController.dismiss(animated: true) {
                                    self.navController = nil
                                    self.presentEmailVerificationFlow()
                                }
                            } else {
                                self.presentEmailVerificationFlow()
                            }
                        } else if shouldShowAddressFlow {
                            if let navController = self.navController {
                                navController.dismiss(animated: true) {
                                    self.navController = nil
                                    self.presentAddressSearchFlow()
                                }
                            } else {
                                self.presentAddressSearchFlow()
                            }
                        } else {
                            self.safePushInNavController(controller)
                        }
                    }
                }, onError: { error in
                    Logger.shared.error("Error getting next page: \(String(describing: error))")
                }, onCompleted: { [weak self] in
                    Logger.shared.info("No more next pages")
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.kycSettings.isCompletingKyc = false
                    strongSelf.finish()
                })
            disposables.insertWithDiscardableResult(disposable)
        }
    }

    private func presentAddressSearchFlow() {
        guard let countryCode = country?.code ?? user?.address?.countryCode else { return }
        addressSearchFlowPresenter
            .openSearchAddressFlow(
                country: countryCode,
                state: user?.address?.state
            )
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveSubscription: { [weak self] _ in self?.handle(event: .pageWillAppear(.address)) })
            .sink(receiveValue: { [weak self] addressResult in
                switch addressResult {
                case .saved:
                    self?.handle(event: .nextPageFromPageType(.address, nil))
                case .abandoned:
                    self?.stop()
                }
            })
            .store(in: &bag)
    }

    private func presentEmailVerificationFlow() {
        guard let rootViewController else {
            return
        }
        presentEmailVerificationIfNeeded(
            from: rootViewController
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] addressResult in
            switch addressResult {
            case .completed, .skipped:
                self?.handle(event: .nextPageFromPageType(.confirmEmail, nil))
            case .abandoned:
                self?.stop()
            }
        })
        .store(in: &bag)
    }

    private func presentEmailVerificationIfNeeded(
        from presenter: UIViewController
    ) -> AnyPublisher<FlowResult, RouterError> {
        emailVerificationService
            // step 1: check email verification status.
            .checkEmailVerificationStatus()
            .mapError { _ in
                RouterError.emailVerificationFailed
            }
            .receive(on: DispatchQueue.main)
            // step 2: present email verification screen, if needed.
            .flatMap { response -> AnyPublisher<FlowResult, RouterError> in
                switch response.status {
                case .verified:
                    // The user's email address is verified; no need to do anything. Just move on.
                    return .just(.skipped)

                case .unverified:
                    // The user's email address in NOT verified; present email verification flow.
                    let publisher = PassthroughSubject<FlowResult, RouterError>()
                    self.routeToEmailVerification(from: presenter, emailAddress: response.emailAddress) { result in
                        // Because the caller of the API doesn't know if the flow got presented, we should dismiss it here
                        presenter.dismiss(animated: true) {
                            switch result {
                            case .abandoned:
                                publisher.send(.abandoned)
                            case .completed:
                                publisher.send(.completed)
                            case .skipped:
                                publisher.send(.skipped)
                            }
                            publisher.send(completion: .finished)
                        }
                    }
                    return publisher.eraseToAnyPublisher()
                }
            }
            .handleEvents(
                receiveOutput: { [app] state in
                    guard state == .completed else { return }
                    app.post(event: blockchain.ux.kyc.event.status.did.change)
                }
            )
            .eraseToAnyPublisher()
    }

    private func routeToEmailVerification(
        from presenter: UIViewController,
        emailAddress: String,
        flowCompletion: @escaping (FlowResult) -> Void
    ) {
        presenter.present(
            EmailVerificationView(
                store: .init(
                    initialState: .init(emailAddress: emailAddress),
                    reducer: buildEmailVerificationReducer(
                        emailAddress: emailAddress,
                        flowCompletion: flowCompletion
                    )
                )
            )
        )
    }

    private func buildEmailVerificationReducer(
        emailAddress: String,
        flowCompletion: @escaping (FlowResult) -> Void
    ) -> EmailVerificationReducer {
        EmailVerificationReducer(
            analyticsRecorder: analyticsRecorder,
            emailVerificationService: emailVerificationService,
            flowCompletionCallback: flowCompletion,
            openMailApp: { [externalAppOpener] in
                    .future { callback in
                        externalAppOpener.openMailApp { result in
                            callback(.success(result))
                        }
                    }
            },
            app: app
        )
    }

    private func presentVerification() {
        tiersService.tiers
            .asSingle()
            .handleLoaderForLifecycle(loader: loadingViewPresenter)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] _ in
                    guard let self else { return }
                    handle(event: .nextPageFromPageType(.states, nil))
                }
            )
            .disposed(by: disposeBag)
    }

    func presentInformationController(_ controller: KYCInformationController) {
        /// Refresh the user's tiers to get their status.
        /// Sometimes we receive an `INTERNAL_SERVER_ERROR` if we refresh this
        /// immediately after submitting all KYC data. So, we apply a delay here.
        tiersService.tiers
            .asSingle()
            .handleLoaderForLifecycle(loader: loadingViewPresenter)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] response in
                    guard let self else { return }
                    let status = response.tierAccountStatus(for: .verified)

                    controller.viewModel = KYCInformationViewModel.create(
                        for: status,
                        isReceivingAirdrop: false
                    )
                    controller.viewConfig = KYCInformationViewConfig.create(
                        for: status,
                        isReceivingAirdrop: false
                    )
                    controller.primaryButtonAction = { _ in
                        switch status {
                        case .failed, .expired:
                            if let blockchainSupportURL = URL(string: Constants.Url.blockchainSupport) {
                                UIApplication.shared.open(blockchainSupportURL)
                            }
                        default:
                            break
                        }
                        self.finish()
                    }

                    safePushInNavController(controller)
                }
            )
            .disposed(by: disposeBag)
    }

    var hasQuestions: Bool {
        (try? app.state.get(blockchain.ux.kyc.extra.questions.form.is.empty)) == false
    }

    // MARK: View Restoration

    /// Restores the user to the most recent page if they dropped off mid-flow while KYC'ing
    private func restoreToMostRecentPageIfNeeded(
        tier: KYC.Tier,
        isNewProfile: Bool,
        isSSNRequired: Bool
    ) {
        guard let currentUser = user else {
            return
        }
        guard let response = userTiersResponse else { return }

        let latestPage = kycSettings.latestKycPage

        let startingPage = KYCPageType.startingPage(
            forUser: currentUser,
            requiredTier: tier,
            tiersResponse: response,
            hasQuestions: hasQuestions,
            isNewProfile: isNewProfile,
            isSSNRequired: isSSNRequired
        )

        if startingPage == .finish {
            return
        }

        if startingPage == .accountStatus {
            /// If their `startingPage` is `.accountStatus`, they're done.
            pager = KYCPager(isNewProfile: isNewProfile, tier: .verified, tiersResponse: response)
        }

        guard let endPageForLastUsedTier = KYCPageType.pageType(
            for: currentUser,
            tiersResponse: response,
            latestPage: latestPage
        ) else {
            return
        }

        // If a user has moved to a new tier, they need to use the starting page for the new tier
        let endPage = endPageForLastUsedTier.rawValue >= startingPage.rawValue ? endPageForLastUsedTier : startingPage

        var currentPage = startingPage
        while currentPage != endPage {
            guard let nextPage = currentPage.nextPage(
                forTier: tier,
                user: user,
                country: country,
                tiersResponse: response,
                isNewProfile: isNewProfile,
                isSSNRequired: isSSNRequired
            ) else { return }

            currentPage = nextPage

            let nextController = pageFactory.createFrom(
                pageType: currentPage,
                in: self,
                payload: createPagePayload(page: currentPage, user: currentUser)
            )

            safePushInNavController(nextController, animated: false)
        }
    }

    private func createPagePayload(page: KYCPageType, user: NabuUser) -> KYCPagePayload? {
        switch page {
        case .confirmPhone:
            return .phoneNumberUpdated(phoneNumber: user.mobile?.phone ?? "")
        case .confirmEmail:
            return .emailPendingVerification(email: user.email.address)
        case .accountStatus:
            guard let response = userTiersResponse else { return nil }
            return .accountStatus(
                status: response.tierAccountStatus(for: .verified),
                isReceivingAirdrop: false
            )
        case .enterEmail,
             .welcome,
             .country,
             .states,
             .profile,
             .profileNew,
             .address,
             .accountUsageForm,
             .enterPhone,
             .verifyIdentity,
             .resubmitIdentity,
             .applicationComplete,
             .ssn,
             .finish:
            return nil
        }
    }

    private func initializeNavigationStack(
        _ viewController: UIViewController,
        user: NabuUser,
        tier: KYC.Tier,
        isNewProfile: Bool,
        isSSNRequired: Bool
    ) {
        guard let response = userTiersResponse else { return }
        let startingPage = KYCPageType.startingPage(
            forUser: user,
            requiredTier: tier,
            tiersResponse: response,
            hasQuestions: hasQuestions,
            isNewProfile: isNewProfile,
            isSSNRequired: isSSNRequired
        )
        if startingPage == .finish {
            return
        }

        checkConfigurations(
            page: startingPage,
            user: user
        ) { [weak self] shouldShowEmailVerification, shouldShowAddressFlow in

            guard let self else { return }
            var controller: KYCBaseViewController
            if startingPage == .accountStatus {
                controller = pageFactory.createFrom(
                    pageType: startingPage,
                    in: self,
                    payload: .accountStatus(
                        status: response.tierAccountStatus(for: .verified),
                        isReceivingAirdrop: false
                    )
                )
                navController = presentInNavigationController(controller, in: viewController)
                return
            }
            if shouldShowEmailVerification {
                presentEmailVerificationFlow()
                return
            }
            if shouldShowAddressFlow {
                presentAddressSearchFlow()
                return
            }
            controller = pageFactory.createFrom(
                pageType: startingPage,
                in: self
            )
            navController = presentInNavigationController(controller, in: viewController)
        }
    }

    // MARK: Private Methods

    private func handlePayloadFromPageType(_ pageType: KYCPageType, _ payload: KYCPagePayload?) {
        guard let payload else { return }
        switch payload {
        case .countrySelected(let country):
            self.country = country
        case .stateSelected(_, let states):
            self.states = states
        case .phoneNumberUpdated,
             .emailPendingVerification,
             .accountStatus:
            // Not handled here
            return
        }
    }

    private func handleFailurePage(for error: KYCPageError) {

        let informationViewController = KYCInformationController.make(with: self)
        informationViewController.viewConfig = KYCInformationViewConfig(
            isPrimaryButtonEnabled: true
        )

        switch error {
        case .countryNotSupported(let country):
            kycSettings.isCompletingKyc = false
            informationViewController.viewModel = KYCInformationViewModel.createForUnsupportedCountry(country)
            informationViewController.primaryButtonAction = { [unowned self] viewController in
                viewController.presentingViewController?.presentingViewController?.dismiss(animated: true)
                let interactor = KYCCountrySelectionInteractor()
                let disposable = interactor.selected(
                    country: country,
                    shouldBeNotifiedWhenAvailable: true
                )
                disposables.insertWithDiscardableResult(disposable)
            }
            safePresentInNavigationController(informationViewController)
        case .stateNotSupported(let state):
            kycSettings.isCompletingKyc = false
            informationViewController.viewModel = KYCInformationViewModel.createForUnsupportedState(state)
            informationViewController.primaryButtonAction = { [unowned self] viewController in
                viewController.presentingViewController?.presentingViewController?.dismiss(animated: true)
                let interactor = KYCCountrySelectionInteractor()
                let disposable = interactor.selected(
                    state: state,
                    shouldBeNotifiedWhenAvailable: true
                )
                disposables.insertWithDiscardableResult(disposable)
            }
            safePresentInNavigationController(informationViewController)
        }
    }

    private func handlePageWillAppear(for type: KYCPageType) {
        if type == .accountStatus || type == .applicationComplete {
            kycSettings.latestKycPage = nil
        } else {
            kycSettings.latestKycPage = type
        }

        // Optionally apply page model
        switch type {
        case .welcome,
             .confirmEmail,
             .country,
             .states,
             .accountStatus,
             .accountUsageForm,
             .applicationComplete,
             .resubmitIdentity,
             .ssn,
             .finish:
            break
        case .enterEmail:
            guard let current = user else { return }
            delegate?.apply(model: .email(current))
        case .profile, .profileNew:
            guard let current = user else { return }
            delegate?.apply(model: .personalDetails(current))
        case .address:
            guard let current = user else { return }
            delegate?.apply(model: .address(current, country, states))
        case .enterPhone, .confirmPhone:
            guard let current = user else { return }
            delegate?.apply(model: .phone(current))
        case .verifyIdentity:
            guard let countryCode = country?.code ?? user?.address?.countryCode else { return }
            delegate?.apply(model: .verifyIdentity(countryCode: countryCode))
        }
    }

    private func post(tier: KYC.Tier) -> AnyPublisher<KYC.UserTiers, NabuNetworkError> {
        let body = KYCTierPostBody(selectedTier: tier)
        let request = requestBuilder.post(
            path: ["kyc", "tiers"],
            body: try? JSONEncoder().encode(body),
            authenticated: true
        )!
        return networkAdapter.perform(request: request)
    }

    private func safePushInNavController(
        _ viewController: UIViewController,
        animated: Bool = true
    ) {
        if let navController {
            navController.pushViewController(viewController, animated: animated)
        } else {
            guard let rootViewController else {
                return
            }
            navController = presentInNavigationController(viewController, in: rootViewController)
        }
    }

    private func safePresentInNavigationController(
        _ viewController: UIViewController
    ) {
        if let navController {
            presentInNavigationController(viewController, in: navController)
        } else {
            guard let rootViewController else {
                return
            }
            navController = presentInNavigationController(viewController, in: rootViewController)
        }
    }

    @discardableResult private func presentInNavigationController(
        _ viewController: UIViewController,
        in presentingViewController: UIViewController
    ) -> KYCOnboardingNavigationController {
        let navController = KYCOnboardingNavigationController.make()
        navController.pushViewController(viewController, animated: false)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .pageSheet
        if let presentedViewController = presentingViewController.presentedViewController {
            presentedViewController.dismiss(animated: true) {
                presentingViewController.enter(into: navController, animated: true)
            }
        } else {
            presentingViewController.enter(into: navController, animated: true)
        }

        return navController
    }
}

extension KYCPageType {

    /// The page type the user should be placed in given the information they have provided
    fileprivate static func pageType(for user: NabuUser, tiersResponse: KYC.UserTiers, latestPage: KYCPageType? = nil) -> KYCPageType? {
        // Note: latestPage is only used by tier 2 flow, for tier 1, we need to infer the page,
        // because the user may need to select the country again.
        let tier = user.tiers?.selected ?? .unverified
        switch tier {
        case .unverified:
            return nil
        case .verified:
            return verifiedPageType(for: user, tiersResponse: tiersResponse, latestPage: latestPage)
        }
    }

    private static func verifiedPageType(for user: NabuUser, tiersResponse: KYC.UserTiers, latestPage: KYCPageType? = nil) -> KYCPageType? {
        if let latestPage {
            return latestPage
        }

        guard let mobile = user.mobile else { return .enterPhone }

        guard mobile.verified else { return .confirmPhone }

        if tiersResponse.canCompleteVerified {
            switch tiersResponse.canCompleteVerified {
            case true:
                return user.needsDocumentResubmission == nil ? .verifyIdentity : .resubmitIdentity
            case false:
                return nil
            }
        }

        guard tiersResponse.canCompleteVerified == false else { return .verifyIdentity }

        return nil
    }
}

extension KYCRouter {

    private typealias OnCompleteCheckConfigurationsParameters = (
        shouldShowEmailVerification: Bool,
        shouldShowAddressFlow: Bool
    )

    private func checkConfigurations(
        page: KYCPageType,
        user: NabuUser?,
        onComplete: @escaping (OnCompleteCheckConfigurationsParameters) -> Void
    ) {
        Task(priority: .userInitiated) { @MainActor in

            var shouldShowEmailVerification: Bool?
            if let user,
               (page == .enterEmail && user.email.address.isNotEmpty) || page == .confirmEmail
            {
                shouldShowEmailVerification = try? await app.publisher(
                    for: blockchain.app.configuration.kyc.email.confirmation.announcement.is.enabled,
                    as: Bool.self
                )
                .await()
                .value
            }

            var shouldShowAddressFlow: Bool?
            if page == .address {
                shouldShowAddressFlow = try? await app.publisher(
                    for: blockchain.app.configuration.addresssearch.kyc.is.enabled,
                    as: Bool.self
                )
                .await()
                .value
            }

            onComplete(OnCompleteCheckConfigurationsParameters(
                shouldShowEmailVerification: shouldShowEmailVerification ?? false,
                shouldShowAddressFlow: shouldShowAddressFlow ?? false
            ))
        }
    }

    private func isNewProfileEnabled(onComplete: @escaping (Bool) -> Void) {
        Task(priority: .userInitiated) { @MainActor in
            let isNewProfileEnabled: Bool? = try? await app.publisher(
                for: blockchain.app.configuration.profile.kyc.is.enabled,
                as: Bool.self
            )
                .await()
                .value
            onComplete(isNewProfileEnabled ?? false)
        }
    }
}
