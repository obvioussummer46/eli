import CoreGraphics
import UIKit

/// EventKit wants a `CGColor`; SwiftUI's `Color` cannot supply one reliably
/// across iOS versions, so the hex string is converted directly.
enum PlatformColorBridge {
    static func cgColor(hex: String) -> CGColor {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt64(value, radix: 16) else {
            return UIColor.systemBlue.cgColor
        }
        return UIColor(red: CGFloat((int >> 16) & 0xFF) / 255,
                       green: CGFloat((int >> 8) & 0xFF) / 255,
                       blue: CGFloat(int & 0xFF) / 255,
                       alpha: 1).cgColor
    }
}
