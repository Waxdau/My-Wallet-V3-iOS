// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Localization
import PlatformKit
import RxDataSources
import ToolKit

public struct AccountPickerCellItem: IdentifiableType {

    // MARK: - Properties

    public enum Presenter {
        case emptyState(LabelContent)
        case withdrawalLocks
        case button(ButtonViewModel)
        case linkedBankAccount(LinkedBankAccount, SingleAccountMultiBadgePresenter)
        case paymentMethodAccount(PaymentMethodAccount)
        case accountGroup(AccountGroup)
        case singleAccount(SingleAccount, AssetAction, SingleAccountMultiBadgePresenter)
    }

    enum Interactor {
        case emptyState
        case withdrawalLocks
        case button(ButtonViewModel)
        case linkedBankAccount(LinkedBankAccount)
        case paymentMethodAccount(PaymentMethodAccount)
        case accountGroup(AccountGroup)
        case singleAccount(SingleAccount)
    }

    public let presenter: Presenter

    public var identity: AnyHashable {
        switch presenter {
        case .emptyState:
            "emptyState"
        case .button:
            "button"
        case .withdrawalLocks:
            "withdrawalLocks"
        case .accountGroup(let account):
            account.identifier
        case .linkedBankAccount(let account, _):
            account.identifier
        case .paymentMethodAccount(let account):
            account.identifier
        case .singleAccount(let account, _, _):
            account.identifier
        }
    }

    public var account: BlockchainAccount? {
        switch presenter {
        case .accountGroup(let account):
            account
        case .linkedBankAccount(let account, _):
            account
        case .paymentMethodAccount(let account):
            account
        case .singleAccount(let account, _, _):
            account
        case .emptyState, .button, .withdrawalLocks:
            nil
        }
    }

    public var isButton: Bool {
        if case .button = presenter {
            true
        } else {
            false
        }
    }

    init(interactor: Interactor, assetAction: AssetAction) {
        switch interactor {
        case .emptyState:
            let labelContent = LabelContent(
                text: LocalizationConstants.Dashboard.Prices.noResults,
                font: .main(.medium, 16),
                color: .darkTitleText,
                alignment: .center
            )
            self.presenter = .emptyState(labelContent)

        case .withdrawalLocks:
            self.presenter = .withdrawalLocks

        case .button(let viewModel):
            self.presenter = .button(viewModel)

        case .linkedBankAccount(let account):
            self.presenter = .linkedBankAccount(
                account,
                .init(account: account, action: assetAction)
            )

        case .paymentMethodAccount(let account):
            self.presenter = .paymentMethodAccount(account)

        case .singleAccount(let account):
            self.presenter = .singleAccount(
                account,
                assetAction,
                .init(account: account, action: assetAction)
            )

        case .accountGroup(let account):
            self.presenter = .accountGroup(account)
        }
    }
}
