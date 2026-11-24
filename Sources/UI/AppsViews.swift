import FossifyCommons
import SwiftUI

/// AppDashboardFragment (apps.xml).
struct AppsView: View {
    @Environment(Router.self) private var router

    var body: some View {
        let apps = SystemSettingsRegistry.apps
        PrefScreen(title: "Apps") {
            if apps.isEmpty {
                PrefFooter("No apps are installed here. The Fossify apps appear when Settings runs inside Fossify Launcher.")
            } else {
                PrefRow("All apps", summary: "See all \(apps.count) apps", icon: "square.grid.2x2") {
                    router.push(.allApps(bySize: false))
                }
            }
            let entries = SystemSettingsRegistry.entries(in: .apps)
            if !entries.isEmpty {
                PrefCategory("General")
                EntryRows(category: .apps)
            }
        }
    }
}

/// ManageApplications: every app, by name or by size (Storage › Apps).
struct AllAppsView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    let bySize: Bool
    @State private var sizes: [String: Int64] = [:]

    var body: some View {
        let apps = SystemSettingsRegistry.apps
        let sorted = bySize ? apps.sorted { (sizes[$0.id] ?? 0) > (sizes[$1.id] ?? 0) }
            : apps.sorted { $0.info.name.localizedCaseInsensitiveCompare($1.info.name) == .orderedAscending }
        PrefScreen(title: bySize ? "Apps" : "All apps") {
            ForEach(sorted) { app in
                Button { router.push(.appInfo(app.id)) } label: {
                    HStack(spacing: 16) {
                        AppIcon(app: app)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.info.name).font(.system(size: 16)).foregroundStyle(palette.textColor)
                            if let size = sizes[app.id] {
                                Text(size.formattedSize).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressedStyle())
            }
        }
        .task {
            let ports = apps.map(\.id)
            sizes = await Task.detached {
                Dictionary(uniqueKeysWithValues: ports.map { ($0, AppDataSpec.of($0).usage().total) })
            }.value
        }
    }
}

/// App header (EntityHeaderController): icon and name.
struct AppHeader: View {
    @Environment(\.palette) private var palette
    let app: SystemAppEntry

    var body: some View {
        VStack(spacing: 8) {
            AppIcon(app: app, size: 64)
            Text(app.info.name).font(.system(size: 22, weight: .medium)).foregroundStyle(palette.textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// ActionButtonsPreference: icon over label, in a row.
struct ActionButton: View {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(palette.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(palette.surface))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressedStyle())
    }
}

/// AppInfoDashboardFragment (app_info_settings.xml).
struct AppInfoView: View {
    @Environment(Router.self) private var router
    let appID: String
    @State private var usage: AppDataSpec.Usage?
    @State private var notificationsOn = true

    var body: some View {
        if let app = registeredApp(appID) {
            let spec = AppDataSpec.of(app.id)
            PrefScreen(title: "App info") {
                AppHeader(app: app)
                HStack(spacing: 12) {
                    ActionButton(title: "Open", icon: "arrow.up.forward.app", action: app.open)
                    ActionButton(title: "Clear cache", icon: "trash") {
                        spec.clearCache()
                        refresh(spec)
                        router.toast = "Cache cleared"
                    }
                    .disabled(spec.cache.isEmpty || (usage?.cache ?? 0) == 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                if sendsNotifications(app) {
                    PrefRow("Notifications", summary: notificationsOn ? "On" : "Off") { router.push(.appNotifications(app.id)) }
                }
                PrefRow("Storage & cache", summary: usage.map { "\($0.total.formattedSize) used in internal storage" } ?? " ") {
                    router.push(.appStorage(app.id))
                }
                if app.settings != nil {
                    PrefRow("Additional settings in the app") { router.push(.appSettings(app.id)) }
                }
            }
            .onAppear {
                notificationsOn = AppNotifications.isEnabled(app.notificationID)
                refresh(spec)
            }
        } else {
            PrefScreen(title: "App info") { PrefFooter("This app is not available.") }
        }
    }

    private func refresh(_ spec: AppDataSpec) {
        Task {
            usage = await Task.detached { spec.usage() }.value
        }
    }
}

@MainActor
func sendsNotifications(_ app: SystemAppEntry) -> Bool {
    AppNotifications.identifierPrefixes[app.notificationID] != nil || NotificationHub.registeredApps.contains(app.notificationID)
}

/// AppStorageSettings (app_storage_settings.xml).
struct AppStorageView: View {
    @Environment(Router.self) private var router
    let appID: String
    @State private var usage = AppDataSpec.Usage()
    @State private var confirmClear = false

    var body: some View {
        if let app = registeredApp(appID) {
            let spec = AppDataSpec.of(app.id)
            PrefScreen(title: "Storage") {
                AppHeader(app: app)
                HStack(spacing: 12) {
                    ActionButton(title: "Clear storage", icon: "trash") { confirmClear = true }
                        .disabled(!spec.isKnown)
                    ActionButton(title: "Clear cache", icon: "trash") {
                        spec.clearCache()
                        refresh(spec)
                    }
                    .disabled(usage.cache == 0)
                }
                .padding(.horizontal, 16)
                PrefCategory("Space used")
                PrefRow("User data", summary: usage.data.formattedSize)
                PrefRow("Cache", summary: usage.cache.formattedSize)
                PrefRow("Total", summary: usage.total.formattedSize)
                if !spec.isKnown {
                    PrefFooter("Settings doesn't know where this app keeps its data.")
                } else {
                    PrefFooter("User data counts the app's private files and its own settings. Files it saved for you (Files › On My iPhone) stay.")
                }
            }
            .onAppear { refresh(spec) }
            .alert("Delete app data?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    spec.clearData()
                    refresh(spec)
                    router.restartMessage = "\(app.info.name) data deleted"
                }
            } message: {
                Text("This app’s data, including files and settings, will be permanently deleted from this device")
            }
        } else {
            PrefScreen(title: "Storage") { PrefFooter("This app is not available.") }
        }
    }

    private func refresh(_ spec: AppDataSpec) {
        Task { usage = await Task.detached { spec.usage() }.value }
    }
}

/// "Additional settings in the app".
struct AppSettingsHost: View {
    let appID: String

    var body: some View {
        if let app = registeredApp(appID), let settings = app.settings {
            settings()
        } else {
            PrefScreen(title: "Settings") { PrefFooter("This app has no settings screen.") }
        }
    }
}
