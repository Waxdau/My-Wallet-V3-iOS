// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import LocalAuthentication
import PlatformKit
import PlatformUIKit
import RxRelay
import RxSwift

final class TodayViewInteractor {

    // MARK: - Services

    let container: SharedContainerUserDefaults

    var isBalanceSyncingEnabled: Bool {
        container.shouldSyncPortfolio
    }

    var assetInteractors: Observable<[TodayExtensionCellInteractor]> {
        .just(
            assetPriceCellInteractors
                .map(TodayExtensionCellInteractor.assetPrice)
        )
    }

    var portfolioInteractor: Observable<TodayExtensionCellInteractor?> {
        .just(
            container.portfolio
                .flatMap(PortfolioCellInteractor.init)
                .flatMap(TodayExtensionCellInteractor.portfolio)
        )
    }

    private let assetPriceCellInteractors: [AssetPriceCellInteractor]
    private let priceService: PriceServiceAPI
    private let enabledCurrenciesService: EnabledCurrenciesServiceAPI
    private let disposeBag = DisposeBag()

    init(
        priceService: PriceServiceAPI = resolve(),
        container: SharedContainerUserDefaults = .default,
        enabledCurrenciesService: EnabledCurrenciesServiceAPI = resolve(),
        fiatCurrencyService: FiatCurrencyServiceAPI = resolve()
    ) {
        self.container = container
        assetPriceCellInteractors = enabledCurrenciesService.allEnabledCryptoCurrencies
            .map { cryptoCurrency in
                AssetPriceCellInteractor(
                    cryptoCurrency: cryptoCurrency,
                    priceService: priceService,
                    fiatCurrencyService: fiatCurrencyService
                )
            }
        self.priceService = priceService
        self.enabledCurrenciesService = enabledCurrenciesService
    }

    /// Returns the supported device biometrics, regardless if currently configured in app
    private var supportsBioAuthentication: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Performs authentication
    private func performAuthentication() -> Single<Void> {
        Single.create { observer -> Disposable in
            let context = LAContext()
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "See your balances",
                reply: { authenticated, error in
                    if let error = error {
                        let biometryError = Biometry.BiometryError(
                            with: error,
                            type: Biometry.BiometryType(with: context.biometryType)
                        )
                        observer(.error(Biometry.EvaluationError.system(biometryError)))
                    } else if !authenticated {
                        observer(.error(Biometry.EvaluationError.notAllowed))
                    } else { // Success
                        observer(.success(()))
                    }
                }
            )
            return Disposables.create()
        }
    }

    func refresh() {
        assetPriceCellInteractors.forEach { interactor in
            interactor.priceViewInteractor.refresh()
        }
    }
}
