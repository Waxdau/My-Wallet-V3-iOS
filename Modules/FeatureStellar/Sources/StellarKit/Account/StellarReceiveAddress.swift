// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import MoneyKit
import Coincore

struct StellarReceiveAddress: CryptoReceiveAddress, QRCodeMetadataProvider {

    let asset: CryptoCurrency = .stellar
    let address: String
    let label: String
    let memo: String?
    let onTxCompleted: (TransactionResult) -> AnyPublisher<Void, Error>

    var qrCodeMetadata: QRCodeMetadata {
        QRCodeMetadata(content: sep7URI.absoluteString, title: address)
    }

    var assetName: String {
        asset.name
    }

    private var sep7URI: SEP7URI { SEP7URI(address: address, amount: nil, memo: memo) }

    init(
        address: String,
        label: String,
        memo: String? = nil,
        onTxCompleted: @escaping (TransactionResult) -> AnyPublisher<Void, Error> = { _ in .empty() }
    ) {
        self.address = address
        self.label = label
        self.memo = memo
        self.onTxCompleted = onTxCompleted
    }
}
