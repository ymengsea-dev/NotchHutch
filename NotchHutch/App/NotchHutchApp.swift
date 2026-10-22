//
//  NotchHutchApp.swift
//  Notch Hutch
//
//  Created by MacBook on 1/8/26.
//

import SwiftUI
import Sparkle

@main
struct NotchHutchApp: App {
    init() {
        CrashReporter.install()
        _ = UpdateManager.shared

        DispatchQueue.main.async {
            NotchWindowController.shared.show()
        }
    }
    
    var body: some Scene {
        Settings {
            AboutSettingsView()
        }
    }
}
