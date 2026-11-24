import FossifyCommons
import Observation
import SwiftUI
import UIKit

enum Route: Hashable {
    case apps
    case allApps(bySize: Bool)
    case appInfo(String)
    case appStorage(String)
    case appNotifications(String)
    case appSettings(String)
    case notifications
    case storage
    case display
    case textReading
    case accessibility
    case security
    case system
    case dateTime
    case backup
    case reset
    /// A registered `SystemSettingsEntry`.
    case entry(String)
    /// The registered entries of a category that has no screen of its own (Wallpaper).
    case category(String)
    case search
    case customizeColors
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var toast: String?
    /// Set after changes that the other apps only pick up on their next start.
    var restartMessage: String?

    func push(_ r: Route) { path.append(r) }
}

/// The whole app as one view: the standalone app's window content, and what the launcher
/// presents. Settings owned by the launcher come from `SystemSettingsRegistry`.
public struct SettingsRoot: View {
    @State private var router = Router()

    public init() {}

    public var body: some View {
        RootView()
            .environment(router)
            .fossifyTheme()
            .appLock()
            .onAppear {
                SystemDisplay.install()
                AppNotifications.install()
                AppNotifications.purgeDisabled()
            }
    }
}

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomepageView()
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                        .toolbar(.hidden, for: .navigationBar)
                        .paletteBackground()
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .toast($router.toast)
        .alert(router.restartMessage ?? "", isPresented: Binding(get: { router.restartMessage != nil },
                                                                 set: { if !$0 { router.restartMessage = nil } })) {
            Button("Restart now", role: .destructive) { exit(0) }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Open apps keep their current state in memory until Fossify restarts.")
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .apps: AppsView()
        case .allApps(let bySize): AllAppsView(bySize: bySize)
        case .appInfo(let id): AppInfoView(appID: id)
        case .appStorage(let id): AppStorageView(appID: id)
        case .appNotifications(let id): AppNotificationsView(appID: id)
        case .appSettings(let id): AppSettingsHost(appID: id)
        case .notifications: NotificationsView()
        case .storage: StorageView()
        case .display: DisplayView()
        case .textReading: TextReadingView()
        case .accessibility: AccessibilityView()
        case .security: SecurityView()
        case .system: SystemView()
        case .dateTime: DateTimeView()
        case .backup: BackupView()
        case .reset: ResetView()
        case .entry(let id): EntryHost(entryID: id)
        case .category(let raw): CategoryEntriesView(category: SystemSettingsEntry.Category(rawValue: raw) ?? .system)
        case .search: SearchView()
        case .customizeColors: CustomizeColorsView()
        }
    }
}

extension AppInfo {
    public static let settings = AppInfo(
        name: "Settings", icon: "gearshape.fill", upstream: "Settings", port: "settings-ios", policy: "settings"
    )
}
