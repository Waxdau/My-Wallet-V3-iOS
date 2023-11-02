// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

public enum DevicePresenter {
    public enum DeviceType: Int, Comparable {
        case superCompact = 1 // SE
        case compact = 2 // 8
        case regular = 3 // Plus, X
        case max = 4 // Max

        public static func < (lhs: DevicePresenter.DeviceType, rhs: DevicePresenter.DeviceType) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public static let type: DeviceType = UIDevice.current.type
}

extension UIDevice {
    private enum PhoneHeight: CGFloat {
        case se = 568
        case eight = 667
        case plus = 736
        case x = 812
        case max = 896
    }

    fileprivate var type: DevicePresenter.DeviceType {
        guard userInterfaceIdiom == .phone
        else { return .regular }
        let size = UIScreen.main.bounds.size
        let height = max(size.width, size.height)
        switch height {
        case let height where height <= PhoneHeight.se.rawValue:
            return .superCompact
        case let height where height <= PhoneHeight.eight.rawValue:
            return .compact
        case let height where height <= PhoneHeight.x.rawValue:
            return .regular
        case let height where height > PhoneHeight.x.rawValue:
            return .max

        default:
            // Impossible case
            return .regular
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func modelName(for machineName: String) -> String {
        switch machineName {
        // iPod Touch line
        case "iPod7,1":
            "iPod Touch 6"
        case "iPod9,1":
            "iPod Touch 7"

        // iPhone 5 line
        case "iPhone6,1", "iPhone6,2":
            "iPhone 5s"

        // iPhone SE line
        case "iPhone8,4":
            "iPhone SE"

        // iPhone 6 line
        case "iPhone7,2":
            "iPhone 6"
        case "iPhone7,1":
            "iPhone 6 Plus"
        case "iPhone8,1":
            "iPhone 6s"
        case "iPhone8,2":
            "iPhone 6s Plus"

        // iPhone 7 line
        case "iPhone9,1", "iPhone9,3":
            "iPhone 7"
        case "iPhone9,2", "iPhone9,4":
            "iPhone 7 Plus"

        // iPhone 8 line
        case "iPhone10,1", "iPhone10,4":
            "iPhone 8"
        case "iPhone10,2", "iPhone10,5":
            "iPhone 8 Plus"

        // iPhone X Line
        case "iPhone10,3", "iPhone10,6":
            "iPhone X"
        case "iPhone11,2":
            "iPhone XS"
        case "iPhone11,4", "iPhone11,6":
            "iPhone XS Max"
        case "iPhone11,8":
            "iPhone XR"

        // iPhone 11 Line
        case "iPhone12,1":
            "iPhone 11"
        case "iPhone12,3":
            "iPhone 11 Pro"
        case "iPhone12,5":
            "iPhone 11 Pro Max"
        case "iPhone12,8":
            "iPhone SE 2nd Gen"

        // iPhone 12 Line
        case "iPhone13,1":
            "iPhone 12 Mini"
        case "iPhone13,2":
            "iPhone 12"
        case "iPhone13,3":
            "iPhone 12 Pro"
        case "iPhone13,4":
            "iPhone 12 Pro Max"

        // iPhone 13 Line
        case "iPhone14,2":
            "iPhone 13 Pro"
        case "iPhone14,3":
            "iPhone 13 Pro Max"
        case "iPhone14,4":
            "iPhone 13 Mini"
        case "iPhone14,5":
            "iPhone 13"

        // iPhone 14 Line
        case "iPhone14,7":
            "iPhone 14"
        case "iPhone14,8":
            "iPhone 14 Plus"
        case "iPhone15,2":
            "iPhone 14 Pro"
        case "iPhone15,3":
            "iPhone 14 Pro Max"

        // iPad Air Line
        case "iPad4,1", "iPad4,2", "iPad4,3":
            "iPad Air"
        case "iPad5,3", "iPad5,4":
            "iPad Air 2"
        case "iPad11,3", "iPad11,4":
            "iPad Air 3"

        // iPad Line
        case "iPad6,11", "iPad6,12":
            "iPad 5"
        case "iPad7,5", "iPad7,6":
            "iPad 6"
        case "iPad7,11", "iPad7,12":
            "iPad 7"

        // iPad Mini Line
        case "iPad4,4", "iPad4,5", "iPad4,6":
            "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":
            "iPad Mini 3"
        case "iPad5,1", "iPad5,2":
            "iPad Mini 4"

        // iPad Pro Line
        case "iPad6,3", "iPad6,4":
            "iPad Pro 9.7 Inch"
        case "iPad6,7", "iPad6,8":
            "iPad Pro 12.9 Inch"
        case "iPad7,1", "iPad7,2":
            "iPad Pro 12.9 Inch 2. Generation"
        case "iPad7,3", "iPad7,4":
            "iPad Pro 10.5 Inch"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":
            "iPad Pro 12.9 Inch 3. Generation"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":
            "iPad Pro 11 Inch"
        case "iPad8,11", "iPad8,12":
            "iPad Pro 12.9 Inch 4. Generation"
        case "iPad8,9", "iPad8,10":
            "iPad Pro 11 Inch 2. Generation"

        case "i386", "x86_64":
            "Simulator"

        default:
            "Unknown device: identifier \(machineName)"
        }
    }

    private var machineName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = Mirror(reflecting: systemInfo.machine)
        let machineName = machine.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        return machineName
    }

    public var modelName: String {
        modelName(for: machineName)
    }
}
