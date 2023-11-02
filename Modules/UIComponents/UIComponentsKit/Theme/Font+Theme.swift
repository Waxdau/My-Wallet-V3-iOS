// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import SwiftUI

extension UIFont {

    private static func fontName(for weight: Typography.Weight) -> String {
        switch weight {
        case .regular:
            Typography.FontResource.interRegular.rawValue
        case .medium:
            Typography.FontResource.interMedium.rawValue
        case .semibold:
            Typography.FontResource.interSemibold.rawValue
        case .bold:
            Typography.FontResource.interBold.rawValue
        }
    }

    public static func main(_ weight: Typography.Weight, _ size: CGFloat) -> UIFont {
        FontLoader.loadCustomFonts()
        let fontName = fontName(for: weight)
        guard let font = UIFont(name: fontName, size: size) else {
            assertionFailure("\(fontName) font does not exist.")
            return UIFont.systemFont(ofSize: size)
        }
        return font
    }
}
