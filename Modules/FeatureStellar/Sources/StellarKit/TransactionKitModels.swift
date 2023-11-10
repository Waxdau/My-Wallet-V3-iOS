// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import MoneyKit

struct SendDetails {
    let fromAddress: String
    let fromLabel: String
    let toAddress: String
    let toLabel: String
    let value: CryptoValue
    let fee: CryptoValue
    let memo: String?
}

enum SendFailureReason: Error {
    /// Takes the account's balance and desired amount
    case insufficientFunds(MoneyValue, MoneyValue)
    /// Takes the minimum limit
    case belowMinimumSend(MoneyValue)
    /// Takes the minimum limit
    case belowMinimumSendNewAccount(MoneyValue)
    case badDestinationAccountID
    case unknown
}

extension SendFailureReason: Equatable {}

struct SendConfirmationDetails {
    let sendDetails: SendDetails
    let fees: CryptoValue
    let transactionHash: String
}
