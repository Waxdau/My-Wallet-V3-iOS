// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import ComposableArchitecture
import Foundation
import SwiftUI

public struct SwapFromAccountRow: Reducer {
    public let app: AppProtocol
    public init(
        app: AppProtocol
    ) {
        self.app = app
    }

    public enum Action: Equatable, BindableAction {
        case onAppear
        case onAccountSelected
        case binding(BindingAction<SwapFromAccountRow.State>)
    }

    public struct State: Equatable, Identifiable {
        public var id: String {
            accountId
        }

        var accountId: String
        var isLastRow: Bool
        var appMode: AppMode?
        @BindingState var price: MoneyValue?
        @BindingState var balance: MoneyValue?
        @BindingState var networkLogo: URL?
        @BindingState var networkName: String?

        var currency: CryptoCurrency? {
            balance?.currency.cryptoCurrency
        }

        var leadingTitle: String {
            currency?.name ?? ""
        }

        var trailingTitle: String {
            balance?.cryptoValue?.toFiatAmount(with: price)?.toDisplayString(includeSymbol: true) ?? ""
        }

        var trailingDescriptionString: String? {
            balance?.toDisplayString(includeSymbol: true) ?? ""
        }

        var trailingDescriptionColor: Color? {
            .semantic.text
        }

        public init(
            isLastRow: Bool,
            accountId: String
        ) {
            self.isLastRow = isLastRow
            self.accountId = accountId
        }
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                state.appMode = app.currentMode
                return .none
            case .onAccountSelected:
                return .none
            }
        }
    }
}

extension SwapFromAccountRow.State {
    var networkTag: TagView? {
        guard let networkName, appMode == .pkw else {
            return nil
        }
        return TagView(text: networkName, variant: .outline)
    }
}
