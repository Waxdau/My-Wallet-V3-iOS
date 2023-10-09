// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import ComposableArchitecture
import DIKit
@testable import FeatureTourUI
import MoneyKit
import SnapshotTesting
import XCTest

final class TourViewTests: XCTestCase {

    override func setUp() {
        _ = App.preview
        super.setUp()
        isRecording = false
    }

//    func testTourView_manualLogin_disabled() {
//        let view = OnboardingCarouselView(
//            store: Store(
//                initialState: TourState(),
//                reducer: NoOpReducer()
//            ),
//            manualLoginEnabled: false
//        )
//        assertSnapshot(
//            matching: view,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let brokerageView = OnboardingCarouselView.Carousel.brokerage.makeView()
//        assertSnapshot(
//            matching: brokerageView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let earnView = OnboardingCarouselView.Carousel.earn.makeView()
//        assertSnapshot(
//            matching: earnView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let keysView = OnboardingCarouselView.Carousel.keys.makeView()
//        assertSnapshot(
//            matching: keysView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let items = [
//            Price(currency: .bitcoin, value: .loaded(next: "$55,343.76"), deltaPercentage: .loaded(next: 7.88)),
//            Price(currency: .ethereum, value: .loaded(next: "$3,585.69"), deltaPercentage: .loaded(next: 1.82)),
//            Price(currency: .bitcoinCash, value: .loaded(next: "$618.05"), deltaPercentage: .loaded(next: -3.46)),
//            Price(currency: .stellar, value: .loaded(next: "$0.36"), deltaPercentage: .loaded(next: 12.50))
//        ]
//        var tourState = TourState()
//        tourState.items = IdentifiedArray(uniqueElements: items)
//
//        let tourStore = Store(
//            initialState: tourState,
//            reducer: NoOpReducer()
//        )
//        let livePricesView = LivePricesView(
//            store: tourStore,
//            list: LivePricesList(store: tourStore)
//        )
//        assertSnapshot(
//            matching: livePricesView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//    }
//
//    func testTourView_manualLogin_enabled() {
//        let view = OnboardingCarouselView(
//            store: Store(
//                initialState: TourState(),
//                reducer: NoOpReducer()
//            ),
//            manualLoginEnabled: true
//        )
//        assertSnapshot(
//            matching: view,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let brokerageView = OnboardingCarouselView.Carousel.brokerage.makeView()
//        assertSnapshot(
//            matching: brokerageView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let earnView = OnboardingCarouselView.Carousel.earn.makeView()
//        assertSnapshot(
//            matching: earnView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let keysView = OnboardingCarouselView.Carousel.keys.makeView()
//        assertSnapshot(
//            matching: keysView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//
//        let items = [
//            Price(currency: .bitcoin, value: .loaded(next: "$55,343.76"), deltaPercentage: .loaded(next: 7.88)),
//            Price(currency: .ethereum, value: .loaded(next: "$3,585.69"), deltaPercentage: .loaded(next: 1.82)),
//            Price(currency: .bitcoinCash, value: .loaded(next: "$618.05"), deltaPercentage: .loaded(next: -3.46)),
//            Price(currency: .stellar, value: .loaded(next: "$0.36"), deltaPercentage: .loaded(next: 12.50))
//        ]
//        var tourState = TourState()
//        tourState.items = IdentifiedArray(uniqueElements: items)
//
//        let tourStore = Store(
//            initialState: tourState,
//            reducer: NoOpReducer()
//        )
//        let livePricesView = LivePricesView(
//            store: tourStore,
//            list: LivePricesList(store: tourStore)
//        )
//        assertSnapshot(
//            matching: livePricesView,
//            as: .image(
//                perceptualPrecision: 0.98,
//                layout: .device(config: .iPhone8Plus),
//                traits: UITraitCollection(userInterfaceStyle: .light)
//            )
//        )
//    }
}

/// This is needed in order to resolve the dependencies
struct MockEnabledCurrenciesServiceAPI: EnabledCurrenciesServiceAPI {
    var allEnabledEVMNetworks: [MoneyKit.EVMNetwork] { [] }
    var allEnabledCurrencies: [CurrencyType] { [] }
    var allEnabledCryptoCurrencies: [CryptoCurrency] { [] }
    var allEnabledFiatCurrencies: [FiatCurrency] { [] }
    var bankTransferEligibleFiatCurrencies: [FiatCurrency] { [] }

    func network(for cryptoCurrency: MoneyKit.CryptoCurrency) -> MoneyKit.EVMNetwork? {
        nil
    }

    func network(for chainId: String) -> EVMNetwork? {
        nil
    }
}

extension DependencyContainer {

    static var mockDependencyContainer = module {
        factory { MockEnabledCurrenciesServiceAPI() as EnabledCurrenciesServiceAPI }
    }
}
