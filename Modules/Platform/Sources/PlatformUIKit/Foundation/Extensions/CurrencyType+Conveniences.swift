// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import MoneyKit
import SwiftUI

extension CurrencyType {

    public var brandColor: Color {
        Color(brandUIColor)
    }

    public var brandUIColor: UIColor {
        switch self {
        case .crypto(let currency):
            currency.brandUIColor
        case .fiat(let currency):
            currency.brandColor
        }
    }
}
