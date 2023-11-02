// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import DIKit
import Errors
import FeatureCardPaymentDomain
import MoneyKit
import RxRelay
import RxSwift
import ToolKit
import WalletPayloadKit

final class EligiblePaymentMethodsService: PaymentMethodsServiceAPI {

    // MARK: - Public properties

    let paymentMethods: Observable<[PaymentMethod]>

    let paymentMethodsSingle: Single<[PaymentMethod]>

    let supportedCardTypes: Single<Set<CardType>>

    // MARK: - Private properties

    private let refreshAction = PublishRelay<Void>()

    private let eligibleMethodsClient: PaymentEligibleMethodsClientAPI
    private let tiersService: KYCTiersServiceAPI
    private let fiatCurrencyService: FiatCurrencySettingsServiceAPI
    private let enabledCurrenciesService: EnabledCurrenciesServiceAPI
    private let applePayEligibilityService: ApplePayEligibleServiceAPI

    private lazy var cache: CachedValueNew<FiatCurrency, [PaymentMethod], Error> = CachedValueNew(
        cache: InMemoryCache(
            configuration: .on(blockchain.user.event.did.update),
            refreshControl: PerpetualCacheRefreshControl()
        ).eraseToAnyCache(),
        fetch: _supportedPaymentMethods(for:)
    )

    // MARK: - Setup

    init(
        eligibleMethodsClient: PaymentEligibleMethodsClientAPI = resolve(),
        tiersService: KYCTiersServiceAPI = resolve(),
        reactiveWallet: ReactiveWalletAPI = resolve(),
        enabledCurrenciesService: EnabledCurrenciesServiceAPI = resolve(),
        fiatCurrencyService: FiatCurrencySettingsServiceAPI = resolve(),
        applePayEligibilityService: ApplePayEligibleServiceAPI = resolve()
    ) {
        self.eligibleMethodsClient = eligibleMethodsClient
        self.tiersService = tiersService
        self.fiatCurrencyService = fiatCurrencyService
        self.enabledCurrenciesService = enabledCurrenciesService
        self.applePayEligibilityService = applePayEligibilityService

        let enabledFiatCurrencies = enabledCurrenciesService.allEnabledFiatCurrencies
        let fetch = fiatCurrencyService.tradingCurrencyPublisher
            .asObservable()
            .flatMap { [tiersService, eligibleMethodsClient] fiatCurrency -> Observable<[PaymentMethod]> in
                let fetchTiers = tiersService.fetchTiers().asSingle()
                return fetchTiers
                .flatMap { tiersResult -> Single<([PaymentMethodsResponse.Method], Bool)> in
                    eligibleMethodsClient.eligiblePaymentMethods(
                        for: fiatCurrency.code,
                        currentTier: tiersResult.latestApprovedTier
                    )
                    .map {
                        ($0, $0.contains { method in method.applePayEligible })
                    }
                    .asSingle()
                }
                .map { methods, applePayEnabled -> [PaymentMethod] in
                    let paymentMethods: [PaymentMethod] = .init(
                        methods: methods,
                        currency: fiatCurrency,
                        supportedFiatCurrencies: enabledFiatCurrencies,
                        enableApplePay: applePayEnabled
                    )
                    .filter(\.isVisible)
                    return paymentMethods
                }
                .map { paymentMethods in
                    paymentMethods.filter { paymentMethod in
                        switch paymentMethod.type {
                        case .card,
                             .bankTransfer,
                             .applePay:
                            true
                        case .funds(let currencyType):
                            currencyType.code == fiatCurrency.code
                        case .bankAccount:
                            // Filter out bank transfer details from currencies we do not
                            //  have local support/UI.
                            enabledFiatCurrencies.contains(paymentMethod.min.currency)
                        }
                    }
                }
                .asObservable()
            }
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        self.paymentMethods = refreshAction
            .startWith(())
            .asObservable()
            .flatMapLatest { _ -> Observable<[PaymentMethod]> in
                fetch
            }
            .share(replay: 1, scope: .whileConnected)

        self.paymentMethodsSingle = fetch
            .take(1)
            .asSingle()

        self.supportedCardTypes = fetch
            .take(1)
            .asSingle()
            .map { paymentMethods in
                guard let card = paymentMethods.first(where: { $0.type.isCard }) else {
                    return []
                }
                switch card.type {
                case .card(let types):
                    return types
                case .bankAccount, .bankTransfer, .funds, .applePay:
                    return []
                }
            }
    }

    func supportedPaymentMethods(for currency: FiatCurrency) -> AnyPublisher<[PaymentMethod], Error> {
        cache.get(key: currency)
    }

    func _supportedPaymentMethods(
        for currency: FiatCurrency
    ) -> AnyPublisher<[PaymentMethod], Error> {
        let enabledFiatCurrencies = enabledCurrenciesService.allEnabledFiatCurrencies
        let fetchTiers = tiersService.fetchTiers().eraseError()
        return fetchTiers
        .flatMap { [eligibleMethodsClient] tiersResult -> AnyPublisher<([PaymentMethodsResponse.Method], Bool), Error> in
            eligibleMethodsClient.eligiblePaymentMethods(
                for: currency.code,
                currentTier: tiersResult.latestApprovedTier
            )
            .map { ($0, $0.contains(where: \.applePayEligible)) }
            .eraseError()
        }
        .map { methods, applePayEnabled -> [PaymentMethod] in
            let paymentMethods: [PaymentMethod] = .init(
                methods: methods,
                currency: currency,
                supportedFiatCurrencies: enabledFiatCurrencies,
                enableApplePay: applePayEnabled
            )
            .filter(\.isVisible)
            return paymentMethods
        }
        .map { paymentMethods in
            paymentMethods.filter { paymentMethod in
                switch paymentMethod.type {
                case .card,
                        .bankTransfer,
                        .applePay:
                    true
                case .funds(let currencyType):
                    currencyType.code == currency.code
                case .bankAccount:
                    // Filter out bank transfer details from currencies we do not
                    //  have local support/UI.
                    enabledFiatCurrencies.contains(paymentMethod.min.currency)
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func refresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshAction.accept(())
        }
    }
}
