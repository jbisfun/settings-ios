import FossifyCommons
import SettingsKit
import SwiftUI

struct SettingsApp: App {
    @UIApplicationDelegateAdaptor(OrientationLockDelegate.self) private var orientation

    var body: some Scene {
        WindowGroup { SettingsRoot() }
    }
}

SettingsApp.main()
