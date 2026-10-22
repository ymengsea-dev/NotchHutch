import SwiftUI
import Combine

final class TabManager: ObservableObject {
    
    static var share = TabManager()
    
    @Published var selectedTab: NotchTab = .home
    
}
