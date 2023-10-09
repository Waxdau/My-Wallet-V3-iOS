// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import ComposableArchitecture
@testable import FeatureKYCDomain
@testable import FeatureKYCUI
import SnapshotTesting
import XCTest

final class LimitedFeaturesListViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    func test_header_contents_for_tier_0() throws {
        let view = LimitedFeaturesListHeader(kycTier: .unverified, action: {})
            .frame(width: 320)
            .fixedSize()

        assertSnapshots(
            matching: view,
            as: [
                .image(
                    perceptualPrecision: 0.98,
                    traits: UITraitCollection(userInterfaceStyle: .light)
                ),
                .image(
                    perceptualPrecision: 0.98,
                    traits: UITraitCollection(userInterfaceStyle: .dark)
                )
            ]
        )
    }

    func test_header_contents_for_tier_2() throws {
        let view = LimitedFeaturesListHeader(kycTier: .verified, action: {})
            .frame(width: 320)
            .fixedSize()

        assertSnapshots(
            matching: view,
            as: [
                .image(traits: UITraitCollection(userInterfaceStyle: .light)),
                .image(traits: UITraitCollection(userInterfaceStyle: .dark))
            ]
        )
    }

    func test_footer_contents() throws {
        let view = LimitedFeaturesListFooter()
            .frame(width: 320)
            .fixedSize()

        assertSnapshots(
            matching: view,
            as: [
                .image(traits: UITraitCollection(userInterfaceStyle: .light)),
                .image(traits: UITraitCollection(userInterfaceStyle: .dark))
            ]
        )
    }

    func test_entire_list_contents() throws {
        _ = App.preview
        let view = LimitedFeaturesListView(
            store: .init(
                initialState: LimitedFeaturesListState(
                    features: [.init(id: .send, enabled: false, limit: nil)],
                    kycTiers: .init(tiers: [])
                ),
                reducer: LimitedFeaturesListReducer(
                    openURL: { _ in },
                    presentKYCFlow: { _ in }
                )
            )
        )
        .frame(width: 320, height: 480)
        .fixedSize()

        assertSnapshots(
            matching: view,
            as: [
                .image(
                    perceptualPrecision: 0.98,
                    traits: UITraitCollection(userInterfaceStyle: .light)
                ),
                .image(
                    perceptualPrecision: 0.98,
                    traits: UITraitCollection(userInterfaceStyle: .dark)
                )
            ]
        )
    }
}
