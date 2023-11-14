// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import BlockchainComponentLibrary
import BlockchainNamespace
import BlockchainUI
import Combine
import ComposableArchitecture
import DIKit
import Errors
import FeatureCustodialOnboarding
import FeatureFormDomain
import FeatureKYCDomain
import Localization
import PlatformKit
import PlatformUIKit
import RxSwift
import SwiftUI
import ToolKit
import UIComponentsKit
import UIKit

public enum FlowResult {
    case abandoned
    case completed
    case skipped
}

public enum RouterError: Error {
    case emailVerificationFailed
    case kycVerificationFailed
    case kycStepFailed
}

private enum UserDefaultsKey: String {
    case didPresentNoticeToUnlockTradingFeatures
}

public protocol Routing {

    /// Uses the passed-in `ViewController`to modally present another `ViewController` wrapping the entire Email Verification Flow.
    /// - Parameters:
    ///   - presenter: The `ViewController` presenting the Email Verification Flow
    ///   - emailAddress: The initial email address to verify. Note that users may change their email address in the course of the verification flow.
    ///   - flowCompletion: A closure called after the Email Verification Flow completes successully (with the email address being verified).
    func routeToEmailVerification(
        from presenter: UIViewController,
        emailAddress: String,
        flowCompletion: @escaping (FlowResult) -> Void
    ) -> UIViewController

    /// Uses the passed-in `ViewController`to modally present another `ViewController` wrapping the entire KYC Flow.
    /// - Parameters:
    ///   - presenter: The `ViewController` presenting the KYC Flow
    ///   - flowCompletion: A closure called after the KYC Flow completes successully (with the email address being verified).
    func routeToKYC(
        from presenter: UIViewController,
        requiredTier: KYC.Tier,
        flowCompletion: @escaping (FlowResult) -> Void
    )

    /// Checks if the user email is verified. If not, the Email Verification Flow will be presented.
    /// Then, the KYC status will be checked against the required tier. If the user is on a lower tier, the KYC Flow will be presented.
    /// - Parameters:
    ///   The `ViewController` presenting the Email Verification and KYC Flows
    ///   - requiredTier: the minimum KYC tier the user needs to be on to avoid presenting the KYC Flow
    func presentEmailVerificationAndKYCIfNeeded(
        from presenter: UIViewController,
        requireEmailVerification: Bool,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError>

    /// Checks if the user email is verified. If not, the Email Verification Flow will be presented.
    /// The `ViewController` presenting the Email Verification Flow Flow
    func presentEmailVerificationIfNeeded(
        from presenter: UIViewController
    ) -> AnyPublisher<FlowResult, RouterError>

    /// Checks the KYC status of the user against the required tier. If the user is on a lower tier, the KYC Flow will be presented.
    /// - Parameters:
    ///   The `ViewController` presenting the KYC Flow
    ///   - requiredTier: the minimum KYC tier the user needs to be on to avoid presenting the KYC Flow
    func presentKYCIfNeeded(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError>

    /// Presents a screen prompting the user to upgrade to Gold Tier. If the user tries to upgrade, the KYC Flow will be presented on top of the prompt.
    /// - Parameter presenter: The `ViewController` that will present the screen
    /// - Returns: A `Combine.Publisher` sending a single value before completing.
    func presentPromptToUnlockMoreTrading(
        from presenter: UIViewController
    ) -> AnyPublisher<FlowResult, Never>

    /// Checks the KYC status of the user against the required tier. If the user is on a lower tier, presents a screen prompting the user to upgrade tier.
    /// If the user tries to upgrade, the KYC Flow will be presented on top of the prompt.
    /// - Parameters:
    ///   - from: the `ViewController` presenting the KYC Flow
    ///   - requiredTier: the minimum KYC tier the user needs to be on to avoid presenting the KYC Flow
    func presentPromptToUnlockMoreTradingIfNeeded(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError>

    /// Presents a limits overview screen
    func presentLimitsOverview(from presenter: UIViewController)
}

/// A class that encapsulates routing logic for the KYC flow. Use this to present the app user with any part of the KYC flow.
public final class Router: Routing {

    private let app: AppProtocol
    private let legacyRouter: PlatformUIKit.KYCRouterAPI
    private let analyticsRecorder: AnalyticsEventRecorderAPI
    private let loadingViewPresenter: PlatformUIKit.LoadingViewPresenting
    private let emailVerificationService: FeatureKYCDomain.EmailVerificationServiceAPI
    private let kycService: PlatformKit.KYCTiersServiceAPI
    private let openMailApp: (@escaping (Bool) -> Void) -> Void
    private let openURL: (URL) -> Void
    private let userDefaults: UserDefaults

    // This should be removed once the legacy router is deleted
    private var cancellables = Set<AnyCancellable>()
    private var disposeBag = DisposeBag()

    public init(
        app: AppProtocol = resolve(),
        analyticsRecorder: AnalyticsEventRecorderAPI,
        loadingViewPresenter: PlatformUIKit.LoadingViewPresenting,
        legacyRouter: PlatformUIKit.KYCRouterAPI,
        kycService: PlatformKit.KYCTiersServiceAPI,
        emailVerificationService: FeatureKYCDomain.EmailVerificationServiceAPI,
        openMailApp: @escaping (@escaping (Bool) -> Void) -> Void,
        openURL: @escaping (URL) -> Void,
        userDefaults: UserDefaults = .standard
    ) {
        self.app = app
        self.analyticsRecorder = analyticsRecorder
        self.loadingViewPresenter = loadingViewPresenter
        self.legacyRouter = legacyRouter
        self.kycService = kycService
        self.emailVerificationService = emailVerificationService
        self.openMailApp = openMailApp
        self.openURL = openURL
        self.userDefaults = userDefaults
    }

    public func routeToEmailVerification(
        from presenter: UIViewController,
        emailAddress: String,
        flowCompletion: @escaping (FlowResult) -> Void
    ) -> UIViewController {
        presenter.present(
            EmailVerificationView(
                store: Store(
                    initialState: .init(emailAddress: emailAddress),
                    reducer: {
                        buildEmailVerificationReducer(
                            emailAddress: emailAddress,
                            mainQueue: .main,
                            pollingQueue: DispatchQueue.global(qos: .background).eraseToAnyScheduler(),
                            flowCompletion: flowCompletion
                        )
                    }
                )
            )
        )
    }

    public func routeToKYC(
        from presenter: UIViewController,
        requiredTier: KYC.Tier,
        flowCompletion: @escaping (FlowResult) -> Void
    ) {
        // NOTE: you must retain the router to get the flow completion
        presentKYC(from: presenter, requiredTier: requiredTier)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: flowCompletion)
            .store(in: &cancellables)
    }

    public func presentKYC(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, Never> {
        app.publisher(for: blockchain.ux.kyc.prove.is.enabled, as: Bool.self)
            .replaceError(with: false)
            .flatMap { [self] isEnabled in
                if isEnabled {
                    presentFlowsKYC(from: presenter, requiredTier: requiredTier)
                } else {
                    presentLegacyKYC(from: presenter, requiredTier: requiredTier)
                }
            }
            .eraseToAnyPublisher()
    }

    @Dependency(\.KYCOnboardingService) var KYCOnboardingService

    private func presentFlowsKYC(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, Never> {
        let subject = PassthroughSubject<FlowResult, Never>()
        return ifEligible(
            subject.handleEvents(
                receiveSubscription: { [KYCOnboardingService] _ in
                    presenter.enter(
                        into: FlowSequenceNavigationController(KYCOnboardingService.flow()) { isFinished in
                            subject.send(isFinished ? .completed : .abandoned)
                        }
                    )
                }
            )
            .eraseToAnyPublisher(),
            presenter: presenter
        )
    }

    public func presentLegacyKYC(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, Never> {
        ifEligible(
            legacyRouter.kycFinished.publisher.replaceOutput(with: FlowResult.completed)
                .merge(with: legacyRouter.kycStopped.publisher.replaceOutput(with: FlowResult.abandoned))
                .prefix(1)
                .handleEvents(receiveSubscription: { [legacyRouter] _ in legacyRouter.start(tier: requiredTier, parentFlow: .simpleBuy) })
                .replaceError(with: FlowResult.abandoned) // should not fail, but just in case
                .eraseToAnyPublisher(),
            presenter: presenter
        )
    }

    public func presentEmailVerificationAndKYCIfNeeded(
        from presenter: UIViewController,
        requireEmailVerification: Bool,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError> {
        // step 1: check email verification status and present email verification flow if email is unverified.
        presentEmailVerificationIfNeeded(from: presenter)
        // step 2: check KYC status and present KYC flow if user has verified their email address.
            .flatMap { [presentKYCIfNeeded] result -> AnyPublisher<FlowResult, RouterError> in
                if requireEmailVerification {
                    switch result {
                    case .abandoned:
                        return .just(.abandoned)
                    case .completed, .skipped:
                        break
                    }
                }
                return presentKYCIfNeeded(presenter, requiredTier)
            }
            .eraseToAnyPublisher()
    }

    public func presentEmailVerificationIfNeeded(
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
                    var viewController: UIViewController?
                    viewController = self.routeToEmailVerification(from: presenter, emailAddress: response.emailAddress) { result in
                        // Because the caller of the API doesn't know if the flow got presented, we should dismiss it here
                        (viewController ?? UIApplication.shared.findTopViewController()).dismiss(animated: true) {
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

    public func presentKYCIfNeeded(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError> {
        guard requiredTier > .unverified else {
            return .just(.skipped)
        }

        // step 1: check KYC status.
        return kycService
            .fetchTiers()
            .receive(on: DispatchQueue.main)
            .mapError { _ in RouterError.kycStepFailed }
            .combineLatest(
                app.publisher(for: blockchain.ux.kyc.SSN.should.be.collected, as: Bool.self)
                    .replaceError(with: false)
                    .prefix(1)
                    .setFailureType(to: RouterError.self)
            )
            .flatMap { [app, routeToKYC] userTiers, isSSNMandatory -> AnyPublisher<FlowResult, RouterError> in

                let presentKYC = Deferred {
                    Future<FlowResult, RouterError> { futureCompletion in
                        routeToKYC(presenter, requiredTier) { result in
                            futureCompletion(.success(result))
                        }
                    }
                }
                    .eraseToAnyPublisher()

                if isSSNMandatory {
                    return presentKYC
                }

                // step 2a: if the current user has extra questions to answer, present kyc
                do {
                    guard try app.state.get(blockchain.ux.kyc.extra.questions.form.is.empty) else {
                        return presentKYC
                    }
                } catch { /* ignore */ }

                // step 2b: if the current user's tier is greater or equal than the required tier, complete.
                guard userTiers.latestApprovedTier < requiredTier else {
                    return .just(.completed)
                }
                // step 2c: else present the kyc flow
                return presentKYC
            }
            .eraseToAnyPublisher()
    }

    public func presentPromptToUnlockMoreTradingIfNeeded(
        from presenter: UIViewController,
        requiredTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, RouterError> {
        guard requiredTier > .unverified else {
            return .just(.skipped)
        }
        let presentClosure = presentPromptToUnlockMoreTrading(from:currentUserTier:)
        return kycService
            .fetchTiers()
            .receive(on: DispatchQueue.main)
            .mapError { _ in RouterError.kycStepFailed }
            .flatMap { userTiers -> AnyPublisher<FlowResult, RouterError> in
                let currentTier = userTiers.latestApprovedTier
                guard currentTier < requiredTier else {
                    return .just(.skipped)
                }
                return presentClosure(presenter, currentTier)
                    .mapError()
            }
            .eraseToAnyPublisher()
    }

    public func presentPromptToUnlockMoreTrading(
        from presenter: UIViewController
    ) -> AnyPublisher<FlowResult, Never> {
        let presentClosure = presentPromptToUnlockMoreTrading(from:currentUserTier:)
        return ifEligible(
            kycService
                .fetchTiers()
                .map(\.latestApprovedTier)
                .replaceError(with: .unverified)
                .receive(on: DispatchQueue.main)
                .flatMap { currentTier -> AnyPublisher<FlowResult, Never> in
                    presentClosure(presenter, currentTier)
                }
                .eraseToAnyPublisher(),
            presenter: presenter
        )
    }

    public func presentLimitsOverview(from presenter: UIViewController) {
        Task {
            guard try await app.get(blockchain.api.nabu.gateway.products["KYC_VERIFICATION"].is.eligible) else { return }
            await MainActor.run {
                let close: () -> Void = { [weak presenter] in
                    presenter?.dismiss(animated: true, completion: nil)
                }
                let presentKYCFlow: (KYC.Tier) -> Void = { [weak self, weak presenter] requiredTier in
                    presenter?.dismiss(animated: true) { [weak self] in
                        guard let self, let presenter else {
                            return
                        }
                        presentKYC(from: presenter, requiredTier: requiredTier)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveValue: { _ in
                                // no-op
                            })
                            .store(in: &cancellables)
                    }
                }
                let app = app
                let view = TradingLimitsView(
                    store: Store(
                        initialState: TradingLimitsState(),
                        reducer: {
                            TradingLimitsReducer(
                                close: close,
                                openURL: openURL,
                                presentKYCFlow: presentKYCFlow,
                                fetchLimitsOverview: kycService.fetchOverview,
                                analyticsRecorder: analyticsRecorder
                            )
                        }
                    )
                )
                    .onAppear {
                        app.post(event: blockchain.ux.kyc.trading.limits.overview)
                    }
                presenter.present(view)
            }
        }
    }

    private func ifEligible<E: Error>(_ publisher: AnyPublisher<FlowResult, E>, presenter: UIViewController) -> AnyPublisher<FlowResult, E> {
        let presentErrorClosure = presentKycDisabledView(from:)
        return app.publisher(for: blockchain.api.nabu.gateway.products["KYC_VERIFICATION"].is.eligible, as: Bool.self)
            .receive(on: DispatchQueue.main)
            .replaceError(with: true)
            .flatMap { isEligible -> AnyPublisher<FlowResult, E> in
                guard isEligible else {
                    return presentErrorClosure(presenter)
                        .mapError()
                }
                return publisher.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Helpers

private typealias L10n = LocalizationConstants.NewKYC
private typealias Events = AnalyticsEvents.New.KYC

extension Router {

    func buildEmailVerificationReducer(
        emailAddress: String,
        mainQueue: AnySchedulerOf<DispatchQueue>,
        pollingQueue: AnySchedulerOf<DispatchQueue>,
        flowCompletion: @escaping (FlowResult) -> Void
    ) -> EmailVerificationReducer {
        let openMailApp = openMailApp
        return EmailVerificationReducer(
            analyticsRecorder: analyticsRecorder,
            emailVerificationService: emailVerificationService,
            flowCompletionCallback: flowCompletion,
            openMailApp: {
                await withCheckedContinuation { continuation in
                    mainQueue.schedule {
                        openMailApp { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
            },
            app: app,
            mainQueue: mainQueue,
            pollingQueue: pollingQueue
        )
    }

    private func presentPromptToUnlockMoreTrading(
        from presenter: UIViewController,
        currentUserTier: KYC.Tier
    ) -> AnyPublisher<FlowResult, Never> {
        let publisher = PassthroughSubject<FlowResult, Never>()
        let view = UnlockTradingView(
            store: Store(
                initialState: UnlockTradingState(currentUserTier: currentUserTier),
                reducer: {
                    UnlockTradingReducer(
                        dismiss: {
                            presenter.dismiss(animated: true) {
                                publisher.send(.abandoned)
                                publisher.send(completion: .finished)
                            }
                        },
                        unlock: { [routeToKYC] requiredTier in
                            routeToKYC(presenter, requiredTier) { result in
                                // KYC is presented on top of prompt. Only dismiss KYC.
                                // KYC id dismissed automatically.
                                // When the kyc flow is abandoned, we don't complete
                                // so users have another shot at going through it
                                guard case .completed = result else {
                                    return
                                }
                                presenter.dismiss(animated: true) {
                                    publisher.send(.completed)
                                    publisher.send(completion: .finished)
                                }
                            }
                        },
                        analyticsRecorder: analyticsRecorder
                    )
                }
            )
        )
            .embeddedInNavigationView()
            .onAppear { [app] in
                app.post(event: blockchain.ux.kyc.trading.upgrade)
            }
        presenter.present(view)
        return publisher.eraseToAnyPublisher()
    }

    private func presentKycDisabledView(
        from presenter: UIViewController
    ) -> AnyPublisher<FlowResult, Never> {
        let publisher = PassthroughSubject<FlowResult, Never>()
        let errorView = ErrorView(
            ux: UX.Error(title: L10n.GenericError.title, message: L10n.GenericError.featureIsNotAvailableMessage),
            dismiss: {
                presenter.dismiss(animated: true) {
                    publisher.send(.abandoned)
                    publisher.send(completion: .finished)
                }
            }
        )

        presenter.present(errorView)
        return publisher.eraseToAnyPublisher()
    }
}
