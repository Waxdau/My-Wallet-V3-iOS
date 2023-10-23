// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import FeatureWalletConnectDomain

extension DependencyContainer {
    // MARK: - FeatureWalletConnectUI Module

    public static var featureWalletConnectUI = module {
        single {
            WalletConnectObserver(
                app: DIKit.resolve(),
                analyticsEventRecorder: DIKit.resolve(),
                service: DIKit.resolve(),
                tabSwapping: { () -> WalletConnectTabSwapping in
                    DIKit.resolve()
                }
            )
        }
    }
}
