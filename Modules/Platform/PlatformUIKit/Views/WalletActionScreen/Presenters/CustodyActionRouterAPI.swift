// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import RxRelay
import RxSwift

public protocol CustodyActionRouterAPI: class {
    func next(to state: CustodyActionStateService.State)
    func previous()
    func start(with account: BlockchainAccount)
    var completionRelay: PublishRelay<Void> { get }
}
