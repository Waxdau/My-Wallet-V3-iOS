// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import FeatureAppUI
import FeatureDashboardUI
import FeatureInterestUI
import FeatureSettingsUI
import MoneyKit
import PlatformKit
import PlatformUIKit

protocol LoggedInDependencyBridgeAPI: AnyObject {
    /// Registers the bridge
    func register(bridge: LoggedInBridge)

    /// Provides `BackupFlowStarterAPI` methods
    func resolveBackupFlowStarter() -> BackupFlowStarterAPI

    /// Provides `SettingsStarterAPI` methods
    func resolveSettingsStarter() -> SettingsStarterAPI

    /// Provides `TabSwapping` methods
    func resolveTabSwapping() -> TabSwapping
    /// Provides `CashIdentityVerificationAnnouncementRouting` methods
    func resolveCashIdentityVerificationAnnouncementRouting() -> CashIdentityVerificationAnnouncementRouting
    /// Provides `AppCoordinating` methods
    func resolveAppCoordinating() -> AppCoordinating
    /// Provides `AuthenticationCoordinating` methods
    func resolveAuthenticationCoordinating() -> AuthenticationCoordinating
    /// Proves `QRCodeScannerRouting` methods
    func resolveQRCodeScannerRouting() -> QRCodeScannerRouting
    /// Provides logout
    func resolveExternalActionsProvider() -> ExternalActionsProviderAPI
}

final class LoggedInDependencyBridge: LoggedInDependencyBridgeAPI {

    private weak var hostingControllerBridge: LoggedInBridge?

    init() {}

    func register(bridge: LoggedInBridge) {
        hostingControllerBridge = bridge
    }

    func resolveBackupFlowStarter() -> BackupFlowStarterAPI {
        resolve() as BackupFlowStarterAPI
    }

    func resolveSettingsStarter() -> SettingsStarterAPI {
        resolve() as SettingsStarterAPI
    }

    func resolveTabSwapping() -> TabSwapping {
        resolve() as TabSwapping
    }

    func resolveCashIdentityVerificationAnnouncementRouting() -> CashIdentityVerificationAnnouncementRouting {
        resolve() as CashIdentityVerificationAnnouncementRouting
    }

    func resolveAppCoordinating() -> AppCoordinating {
        resolve() as AppCoordinating
    }

    func resolveAuthenticationCoordinating() -> AuthenticationCoordinating {
        resolve() as AuthenticationCoordinating
    }

    func resolveQRCodeScannerRouting() -> QRCodeScannerRouting {
        resolve() as QRCodeScannerRouting
    }

    func resolveExternalActionsProvider() -> ExternalActionsProviderAPI {
        resolve() as ExternalActionsProviderAPI
    }

    /// Resolves the underlying bridge with a type
    /// - precondition: The bridge should conform to the type
    /// - Returns: The underlying bridge as a specific protocol type
    private func resolve<T>() -> T {
        precondition(hostingControllerBridge != nil, "No bridge detected, please first use register(bridge:) method")
        precondition(hostingControllerBridge is T, "Bridge does not conform to \(T.self) protocol")
        return hostingControllerBridge as! T
    }
}

final class DynamicDependencyBridge: UIViewController, LoggedInBridge {
    private var wrapped: LoggedInBridge = SignedOutDependencyBridge()

    func register(bridge: LoggedInBridge) {
        wrapped = bridge
    }

    func send(from account: BlockchainAccount) { wrapped.send(from: account) }
    func send(from account: BlockchainAccount, target: TransactionTarget) { wrapped.send(from: account, target: target) }
    func sign(from account: BlockchainAccount, target: TransactionTarget) { wrapped.sign(from: account, target: target) }
    func receive(into account: BlockchainAccount) { wrapped.receive(into: account) }
    func withdraw(from account: BlockchainAccount) { wrapped.withdraw(from: account) }
    func deposit(into account: BlockchainAccount) { wrapped.deposit(into: account) }
    func interestTransfer(into account: BlockchainAccount) { wrapped.interestTransfer(into: account) }
    func interestWithdraw(from account: BlockchainAccount, target: TransactionTarget) { wrapped.interestWithdraw(from: account, target: target) }
    func switchToSend() { wrapped.switchToSend() }
    func switchToActivity() { wrapped.switchToActivity() }
    func startBackupFlow() { wrapped.startBackupFlow() }
    func showSettingsView() { wrapped.showSettingsView() }
    func presentKYCIfNeeded() { wrapped.presentKYCIfNeeded() }
    func presentBuyIfNeeded(_ cryptoCurrency: CryptoCurrency) { wrapped.presentBuyIfNeeded(cryptoCurrency) }
    func enableBiometrics() { wrapped.enableBiometrics() }
    func changePin() { wrapped.changePin() }
    func showQRCodeScanner() { wrapped.showQRCodeScanner() }
    func showCashIdentityVerificationScreen() { wrapped.showCashIdentityVerificationScreen() }
    func showFundTrasferDetails(fiatCurrency: FiatCurrency, isOriginDeposit: Bool) { wrapped.showFundTrasferDetails(fiatCurrency: fiatCurrency, isOriginDeposit: isOriginDeposit) }
    func logout() { wrapped.logout() }
    func handleSupport() { wrapped.handleSupport() }
    func handleSecureChannel() { wrapped.handleSecureChannel() }
    func logoutAndForgetWallet() { wrapped.logoutAndForgetWallet() }
    func exitToPinScreen() { wrapped.exitToPinScreen() }
}

class SignedOutDependencyBridge: UIViewController, LoggedInBridge {
    func exitToPinScreen() {}
    func send(from account: BlockchainAccount) {}
    func send(from account: BlockchainAccount, target: TransactionTarget) {}
    func sign(from account: BlockchainAccount, target: TransactionTarget) {}
    func receive(into account: BlockchainAccount) {}
    func withdraw(from account: BlockchainAccount) {}
    func deposit(into account: BlockchainAccount) {}
    func interestTransfer(into account: BlockchainAccount) {}
    func interestWithdraw(from account: BlockchainAccount, target: TransactionTarget) {}
    func switchToSend() {}
    func switchToActivity() {}
    func startBackupFlow() {}
    func showSettingsView() {}
    func presentKYCIfNeeded() {}
    func presentBuyIfNeeded(_ cryptoCurrency: CryptoCurrency) {}
    func enableBiometrics() {}
    func changePin() {}
    func showQRCodeScanner() {}
    func showCashIdentityVerificationScreen() {}
    func showFundTrasferDetails(fiatCurrency: FiatCurrency, isOriginDeposit: Bool) {}
    func logout() {}
    func handleSupport() {}
    func handleSecureChannel() {}
    func logoutAndForgetWallet() {}
}
