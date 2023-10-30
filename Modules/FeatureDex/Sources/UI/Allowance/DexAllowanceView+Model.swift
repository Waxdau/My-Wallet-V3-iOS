// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import DelegatedSelfCustodyDomain
import DIKit
import FeatureDexData
import FeatureDexDomain
import SwiftUI

extension DexAllowanceView {
    final class Model: ObservableObject {

        @Dependency(\.mainQueue) var mainQueue
        @Dependency(\.transactionCreationService) var service
        var cryptocurrency: CryptoCurrency
        var allowanceSpender: String
        var network: EVMNetwork?
        var didApprove: Bool = false
        @Published var output: Result<DelegatedCustodyTransactionOutput, UX.Error>?
        @Published var didFinish: Bool = false

        init(
            cryptocurrency: CryptoCurrency,
            allowanceSpender: String,
            network: EVMNetwork?
        ) {
            self.allowanceSpender = allowanceSpender
            self.cryptocurrency = cryptocurrency
            self.network = network
        }

        func onAppear() {
            service
                .buildAllowance(token: cryptocurrency, allowanceSpender: allowanceSpender)
                .receive(on: mainQueue)
                .assign(to: &$output)
        }

        func approve(app: AppProtocol) {
            service
                .signAndPush(token: cryptocurrency, output: output?.success)
                .handleEvents(receiveOutput: { [app] output in
                    switch output {
                    case .success(let transactionId):
                        app.post(
                            value: transactionId,
                            of: blockchain.ux.currency.exchange.dex.allowance.transactionId
                        )
                    case .failure:
                        break
                    }
                })
                .replaceOutput(with: true)
                .receive(on: mainQueue)
                .assign(to: &$didFinish)
        }
    }
}
