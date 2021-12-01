// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import MoneyKit
import RxSwift

final class FundsAndBankOrderCreationService: PendingOrderCreationServiceAPI {

    private let paymentAccountService: PaymentAccountServiceAPI
    private let orderQuoteService: OrderQuoteServiceAPI
    private let orderCreationService: OrderCreationServiceAPI

    init(
        paymentAccountService: PaymentAccountServiceAPI = resolve(),
        orderQuoteService: OrderQuoteServiceAPI = resolve(),
        orderCreationService: OrderCreationServiceAPI = resolve()
    ) {
        self.paymentAccountService = paymentAccountService
        self.orderQuoteService = orderQuoteService
        self.orderCreationService = orderCreationService
    }

    func create(using candidateOrderDetails: CandidateOrderDetails) -> Single<PendingConfirmationCheckoutData> {
        let quote = orderQuoteService
            .getQuote(
                for: .simpleBuy,
                sourceCurrency: candidateOrderDetails.fiatCurrency,
                destinationCurrency: candidateOrderDetails.cryptoCurrency,
                amount: MoneyValue(fiatValue: candidateOrderDetails.fiatValue),
                paymentMethod: candidateOrderDetails.paymentMethod?.method.rawType,
                paymentMethodId: candidateOrderDetails.paymentMethodId
            )

        let paymentAccount = paymentAccountService
            .paymentAccount(for: candidateOrderDetails.fiatValue.currency)

        return Single
            .zip(quote, paymentAccount)
            .map { (quote: $0.0, account: $0.1) }
            .flatMap { [orderCreationService] payload in
                orderCreationService.create(using: candidateOrderDetails)
                    .map { checkoutData in
                        PendingConfirmationCheckoutData(
                            quote: payload.quote,
                            checkoutData: checkoutData.checkoutData(byAppending: payload.account)
                        )
                    }
            }
    }
}
