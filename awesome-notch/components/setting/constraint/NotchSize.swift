import SwiftUI

enum NotchSize: CGFloat, CaseIterable {
    case small = 450 // default
    case medium = 500
    // .large (600) removed — nobody used it, and it dwarfed the actual notch.

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        }
    }
}
