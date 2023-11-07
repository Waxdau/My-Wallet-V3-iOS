// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

public enum WalletConnectSupportedMethods: String, CaseIterable {
    case ethSendTransaction = "eth_sendTransaction"
    case ethSignTransaction = "eth_signTransaction"
    case ethSign = "eth_sign"
    case ethSignTypedData = "eth_signTypedData"
    case ethSignTypedDatav4 = "eth_signTypedData_v4"
    case personalSign = "personal_sign"

    public static var allMethods: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}

public enum WalletConnectSignMethod: String {
    case personalSign = "personal_sign"
    case ethSign = "eth_sign"
    case ethSignTypedData = "eth_signTypedData"
    case ethSignTypedDatav4 = "eth_signTypedData_v4"

    private var dataIndex: Int {
        switch self {
        case .personalSign:
            0
        case .ethSign, .ethSignTypedData, .ethSignTypedDatav4:
            1
        }
    }

    private var addressIndex: Int {
        switch self {
        case .personalSign:
            1
        case .ethSign, .ethSignTypedData, .ethSignTypedDatav4:
            0
        }
    }

    func address(from params: [String]) -> String? {
        guard addressIndex <= params.count else {
            return nil
        }
        return params[addressIndex]
    }

    func message(from params: [String]) -> String? {
        guard dataIndex <= params.count else {
            return nil
        }
        return params[dataIndex]
    }
}
