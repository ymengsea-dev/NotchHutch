import SwiftUI

enum NotchTab {
    case home
    case file
    case webcam
}

struct NotchTabContainer: View {
    @ObservedObject var tabManager = TabManager.share
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        NavigationStack{
            HStack{
                HStack{
                    // home tab
                    Button{
                        tabManager.selectedTab = .home
                    }label: {
                        Image(systemName: "house.fill")
                            .foregroundStyle(.white)
                            .frame(width: 35, height: 20)
                            .background(
                                tabManager.selectedTab == .home ? .gray.opacity(0.5) : .clear
                            )
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    // file tab
                    Button{
                        tabManager.selectedTab = .file
                    }label: {
                        Image(systemName: "tray.fill")
                            .foregroundStyle(.white)
                            .frame(width: 35, height: 20)
                            .background(tabManager.selectedTab == .file ? .gray.opacity(0.5) : .clear)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
                HStack{
                    if settings.isWebcamTabEnabled{
                        Button{
                            tabManager.selectedTab = .webcam
                        }label: {
                            Image(systemName: "web.camera")
                                .foregroundStyle(.white)
                                .frame(width: 35, height: 20)
                                .background(
                                    tabManager.selectedTab == .webcam ? .gray
                                        .opacity(0.5) : .clear
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // settings button
                    Button{
                        NotchWindowController.shared.showSettingsWindow()
                    }label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white)
                            .frame(width: 35, height: 20)
                    }
                    .buttonStyle(.plain)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .topTrailing
                )
            }
            VStack{
                switch tabManager.selectedTab {
                case .home:
                    HomeTabView()
                case .file:
                    FileShelfTabView()
                case .webcam:
                    WebcamTabView()
                }
            }.padding(.top, 10)
            
        }
    }
}

#Preview {
    NotchTabContainer()
}

