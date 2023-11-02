// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import BlockchainComponentLibrary
import DIKit
import Errors
import Localization
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift
import ToolKit

public final class FundsTransferDetailScreenPresenter: DetailsScreenPresenterAPI {

    // MARK: - Types

    private typealias AnalyticsEvent = AnalyticsEvents.SimpleBuy
    private typealias LocalizedString = LocalizationConstants.SimpleBuy.TransferDetails
    private typealias AccessibilityId = Accessibility.Identifier.SimpleBuy.TransferDetails

    // MARK: - Screen Properties

    public let reloadRelay: PublishRelay<Void> = .init()
    public let backRelay: PublishRelay<Void> = .init()

    public private(set) var buttons: [ButtonViewModel] = []

    public private(set) var cells: [DetailsScreen.CellType] = []

    // MARK: - Navigation Properties

    public let navigationBarTrailingButtonAction: DetailsScreen.BarButtonAction
    public let navigationBarLeadingButtonAction: DetailsScreen.BarButtonAction = .default

    public var navigationBarAppearance: DetailsScreen.NavigationBarAppearance {
        .custom(
            leading: .none,
            trailing: .close,
            barStyle: .darkContent(ignoresStatusBar: false, background: .white)
        )
    }

    public let titleViewRelay: BehaviorRelay<Screen.Style.TitleView> = .init(value: .none)

    // MARK: - Private Properties

    private let disposeBag = DisposeBag()

    // MARK: - Injected

    private let isOriginDeposit: Bool
    private let analyticsRecorder: AnalyticsEventRecorderAPI
    private let webViewRouter: WebViewRouterAPI
    private let interactor: FundsTransferDetailsInteractorAPI
    private let onError: (UX.Error) -> Void

    // MARK: - Setup

    public init(
        webViewRouter: WebViewRouterAPI,
        analyticsRecorder: AnalyticsEventRecorderAPI = resolve(),
        interactor: FundsTransferDetailsInteractorAPI,
        isOriginDeposit: Bool,
        onError: @escaping (UX.Error) -> Void
    ) {
        self.analyticsRecorder = analyticsRecorder
        self.webViewRouter = webViewRouter
        self.interactor = interactor
        self.isOriginDeposit = isOriginDeposit
        self.onError = onError

        self.navigationBarTrailingButtonAction = .custom { [backRelay] in
            backRelay.accept(())
        }
    }

    public func viewDidLoad() {
        analyticsRecorder.record(
            event: AnalyticsEvents.SimpleBuy.sbLinkBankScreenShown(currencyCode: interactor.fiatCurrency.code)
        )

        interactor.state
            .bindAndCatch(weak: self) { (self, state) in
                switch state {
                case .invalid(.ux(let error)):
                    self.onError(error)
                case .invalid(.valueCouldNotBeCalculated):
                    self.analyticsRecorder.record(
                        event: AnalyticsEvents.SimpleBuy.sbLinkBankLoadingError(
                            currencyCode: self.interactor.fiatCurrency.code
                        )
                    )
                    self.error()
                case .value(let account):
                    self.setup(account: account)
                case .calculating, .invalid(.empty):
                    break
                }
            }
            .disposed(by: disposeBag)
    }

    private func error() {
        titleViewRelay.accept(.text(value: LocalizedString.error))
        let continueButtonViewModel = ButtonViewModel.primary(with: LocalizedString.Button.ok)
        continueButtonViewModel.tapRelay
            .bindAndCatch(to: backRelay)
            .disposed(by: disposeBag)
        buttons.append(continueButtonViewModel)
    }

    private func setup(account: PaymentAccountDescribing) {
        let contentReducer = ContentReducer(
            account: account,
            isOriginDeposit: isOriginDeposit,
            analyticsRecorder: analyticsRecorder
        )

        // MARK: Nav Bar

        titleViewRelay.accept(.text(value: contentReducer.title))

        // MARK: Continue Button Setup

        let continueButtonViewModel = ButtonViewModel.primary(with: LocalizedString.Button.ok)
        continueButtonViewModel.tapRelay
            .bindAndCatch(to: backRelay)
            .disposed(by: disposeBag)
        buttons.append(continueButtonViewModel)

        // MARK: Cells Setup

        contentReducer.lineItems
            .forEach { cells.append(.lineItem($0)) }
        cells.append(.separator)
        for noticeViewModel in contentReducer.noticeViewModels {
            cells.append(.notice(noticeViewModel))
        }

        if let termsTextViewModel = contentReducer.termsTextViewModel {
            termsTextViewModel.tap
                .bindAndCatch(to: webViewRouter.launchRelay)
                .disposed(by: disposeBag)
            cells.append(.interactableTextCell(termsTextViewModel))
        }

        reloadRelay.accept(())
    }
}

// MARK: - Content Reducer

extension FundsTransferDetailScreenPresenter {

    final class ContentReducer {

        let title: String
        let lineItems: [LineItemCellPresenting]
        let noticeViewModels: [NoticeViewModel]
        let termsTextViewModel: InteractableTextViewModel!

        init(
            account: PaymentAccountDescribing,
            isOriginDeposit: Bool,
            analyticsRecorder: AnalyticsEventRecorderAPI
        ) {

            typealias FundsString = LocalizedString.Funds

            if isOriginDeposit {
                self.title = "\(FundsString.Title.depositPrefix) \(account.currency)"
            } else {
                self.title = "\(FundsString.Title.addBankPrefix) \(account.currency) \(FundsString.Title.addBankSuffix) "
            }

            self.lineItems = account.fields.transferDetailsCellsPresenting(analyticsRecorder: analyticsRecorder)

            let font = UIFont.main(.medium, 12)

            let processingTimeNoticeDescription: String

            switch account.currency {
            case .GBP:
                processingTimeNoticeDescription = FundsString.Notice.ProcessingTime.Description.GBP
                self.termsTextViewModel = InteractableTextViewModel(
                    inputs: [
                        .text(string: FundsString.Notice.recipientNameGBPPrefix),
                        .url(string: " \(FundsString.Notice.termsAndConditions) ", url: TermsUrlLink.gbp),
                        .text(string: FundsString.Notice.recipientNameGBPSuffix)
                    ],
                    textStyle: .init(color: .semantic.body, font: font),
                    linkStyle: .init(color: .semantic.primary, font: font)
                )
            case .EUR:
                processingTimeNoticeDescription = FundsString.Notice.ProcessingTime.Description.EUR
                self.termsTextViewModel = InteractableTextViewModel(
                    inputs: [.text(string: FundsString.Notice.recipientNameEUR)],
                    textStyle: .init(color: .semantic.body, font: font),
                    linkStyle: .init(color: .semantic.primary, font: font)
                )
            case .USD:
                processingTimeNoticeDescription = FundsString.Notice.ProcessingTime.Description.USD
                self.termsTextViewModel = nil
            case .ARS:
                processingTimeNoticeDescription = FundsString.Notice.ProcessingTime.Description.ARS
                self.termsTextViewModel = nil
            case .BRL:
                processingTimeNoticeDescription = FundsString.Notice.ProcessingTime.Description.BRL
                self.termsTextViewModel = nil
            default:
                processingTimeNoticeDescription = ""
                self.termsTextViewModel = nil
            }

            self.noticeViewModels = [
                (
                    title: FundsString.Notice.BankTransferOnly.title,
                    description: FundsString.Notice.BankTransferOnly.description,
                    image: ImageLocation.local(name: "icon-bank", bundle: .platformUIKit)
                ),
                (
                    title: FundsString.Notice.ProcessingTime.title,
                    description: processingTimeNoticeDescription,
                    image: ImageLocation.local(name: "clock-icon", bundle: .platformUIKit)
                )
            ]
            .map {
                NoticeViewModel(
                    imageViewContent: ImageViewContent(
                        imageResource: $0.image,
                        renderingMode: .template(.semantic.title)
                    ),
                    labelContents: [
                        LabelContent(
                            text: $0.title,
                            font: .main(.semibold, 12),
                            color: .semantic.title
                        ),
                        LabelContent(
                            text: $0.description,
                            font: .main(.medium, 12),
                            color: .semantic.body
                        )
                    ],
                    verticalAlignment: .top
                )
            }
        }
    }
}

extension [PaymentAccountProperty.Field] {
    private typealias AccessibilityId = Accessibility.Identifier.SimpleBuy.TransferDetails

    fileprivate func transferDetailsCellsPresenting(analyticsRecorder: AnalyticsEventRecorderAPI) -> [LineItemCellPresenting] {

        func isCopyable(field: TransactionalLineItem) -> Bool {
            switch field {
            case .paymentAccountField(.accountNumber),
                 .paymentAccountField(.iban),
                 .paymentAccountField(.bankCode),
                 .paymentAccountField(.sortCode):
                true
            case .paymentAccountField(.field(_, _, _, copy: let copy)):
                copy
            default:
                false
            }
        }

        func analyticsEvent(field: TransactionalLineItem) -> AnalyticsEvents.SimpleBuy? {
            switch field {
            case .paymentAccountField:
                .sbLinkBankDetailsCopied
            default:
                nil
            }
        }

        return map { TransactionalLineItem.paymentAccountField($0) }
            .map { field in
                if isCopyable(field: field) {
                    field.defaultCopyablePresenter(
                        analyticsEvent: analyticsEvent(field: field),
                        analyticsRecorder: analyticsRecorder,
                        accessibilityIdPrefix: AccessibilityId.lineItemPrefix
                    )
                } else {
                    field.defaultPresenter(accessibilityIdPrefix: AccessibilityId.lineItemPrefix)
                }
            }
    }
}
