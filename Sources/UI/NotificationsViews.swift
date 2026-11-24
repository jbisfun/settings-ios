import FossifyCommons
import SwiftUI
import UIKit
import UserNotifications

/// ConfigureNotificationSettings (configure_notification_settings.xml).
struct NotificationsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var phase
    @State private var permission: UNAuthorizationStatus?
    @State private var disabled = AppNotifications.disabledApps

    var body: some View {
        let apps = SystemSettingsRegistry.apps.filter(sendsNotifications)
        PrefScreen(title: "Notifications") {
            PrefCategory("Manage")
            if apps.isEmpty {
                PrefFooter("No app here sends notifications. Calendar, Clock and Messages appear when Settings runs inside Fossify Launcher.")
            }
            ForEach(apps) { app in
                Toggle(isOn: Binding(get: { !disabled.contains(app.notificationID) }, set: { on in
                    AppNotifications.setEnabled(app.notificationID, on)
                    disabled = AppNotifications.disabledApps
                })) {
                    HStack(spacing: 16) {
                        AppIcon(app: app, size: 36)
                        Text(app.info.name).font(.system(size: 16)).foregroundStyle(palette.textColor)
                    }
                }
                .toggleStyle(CheckmarkSwitchStyle())
                .tint(palette.primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            PrefCategory("Privacy")
            PrefRow("Notification permission", summary: permissionSummary, icon: "bell.badge") {
                Launcher.open(URL(string: UIApplication.openNotificationSettingsURLString))
            }
            if !SystemSettingsRegistry.entries(in: .notifications).isEmpty {
                PrefCategory("General")
                EntryRows(category: .notifications)
            }
        }
        .task(id: phase) {
            permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            disabled = AppNotifications.disabledApps
        }
    }

    private var permissionSummary: String {
        switch permission {
        case .authorized, .provisional, .ephemeral: return "Allowed. Sounds, banners and lock screen are set in iOS Settings"
        case .denied: return "Off for all Fossify apps. Turn on in iOS Settings"
        case .notDetermined: return "Asked when an app first sends a notification"
        default: return " "
        }
    }
}

/// AppNotificationSettings (app_notification_settings.xml): the main "block" switch.
struct AppNotificationsView: View {
    @Environment(\.palette) private var palette
    let appID: String
    @State private var on = true

    var body: some View {
        if let app = registeredApp(appID) {
            PrefScreen(title: "Notifications") {
                AppHeader(app: app)
                Toggle(isOn: Binding(get: { on }, set: { v in
                    on = v
                    AppNotifications.setEnabled(app.notificationID, v)
                })) {
                    Text("All \(app.info.name) notifications").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(on ? palette.onPrimary : palette.textColor)
                }
                .toggleStyle(CheckmarkSwitchStyle())
                .tint(palette.onPrimary.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(on ? palette.primaryColor : palette.surface))
                .padding(.horizontal, 16)
                PrefFooter(on ? "Notifications from this app are shown."
                              : "Notifications from this app are blocked: they are not shown while Fossify is open and are removed before they can show later.")
            }
            .onAppear { on = AppNotifications.isEnabled(app.notificationID) }
        }
    }
}
