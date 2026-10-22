import SwiftUI

struct SettingsWindowView: View {
    
    @State private var selection: SettingsSection? = .general
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .media:
                MusicControlSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .shelf:
                FileShelfSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .webcam:
                WebcamSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .appearance:
                AppearanceSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .about:
                AboutSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(settings)
            case .none:
                EmptyView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case media
    case shelf
    case webcam
    case appearance
    case about
    
    var id: String {rawValue}
    
    var title: String{
        rawValue.capitalized
    }
    
    var icon: String{
        switch self {
        case .general: return "gear"
        case .media: return "music.note"
        case .shelf: return "tray.fill"
        case .webcam: return "web.camera"
        case .appearance: return "eye"
        case .about: return "exclamationmark.circle"
        }
    }
}

