import Foundation

extension UserDefaults {
    /// Private settings domain for this app.
    ///
    /// The app's bundle identifier is `com.apple.ControlCenter` (required for
    /// MediaRemote now-playing access on macOS 15.4+), which means plain
    /// UserDefaults.standard writes into the REAL system Control Center's
    /// preferences file. All app settings therefore live in this explicit
    /// suite instead.
    static let awesomeNotch: UserDefaults = {
        let suite = UserDefaults(suiteName: "com.ymengsea.awesome-notch.settings") ?? .standard
        migrateFromStandardDefaultsIfNeeded(into: suite)
        return suite
    }()

    private static func migrateFromStandardDefaultsIfNeeded(into suite: UserDefaults) {
        let migrationFlag = "didMigrateFromStandardDefaults"
        guard suite.object(forKey: migrationFlag) == nil else { return }

        // Exactly the keys this app ever wrote — never touch anything else in
        // the com.apple.ControlCenter domain, it belongs to the system.
        let appKeys = [
            "notchSize", "notchColor", "expandSensitivity", "isLaunchAtLogin",
            "isEnableAirDrop", "isSyncWithMission", "colorSpectrum",
            "notchBorder", "NotchBorderColor", "overflowNotchWhenPlaying",
            "isOpenFileWhenHasItem", "isGrabBunch", "isEnableWebcame",
            "webcameShape", "isKeepNotchExtendedWhenCameraOn", "isEnableWebcameTab"
        ]
        for key in appKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                suite.set(value, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        suite.set(true, forKey: migrationFlag)
    }
}
