import FossifyCommons
import SwiftUI

/// top_level_settings.xml, minus the categories with nothing configurable on iOS.
enum TopLevel: String, CaseIterable, Identifiable {
    case apps, notifications, storage, display, wallpaper, accessibility, security, system

    var id: String { rawValue }

    init?(category: SystemSettingsEntry.Category) { self.init(rawValue: category.rawValue) }

    var category: SystemSettingsEntry.Category { SystemSettingsEntry.Category(rawValue: rawValue)! }

    var title: String {
        switch self {
        case .apps: return "Apps"
        case .notifications: return "Notifications"
        case .storage: return "Storage"
        case .display: return "Display"
        case .wallpaper: return "Wallpaper"
        case .accessibility: return "Accessibility"
        case .security: return "Security & privacy"
        case .system: return "System"
        }
    }

    /// The AOSP dashboard summaries, trimmed to what the screen holds here.
    var summary: String {
        switch self {
        case .apps: return "App info, storage, default apps"
        case .notifications: return "App notifications"
        case .storage: return ""
        case .display: return "Dark theme, font size, brightness"
        case .wallpaper: return "Home screen"
        case .accessibility: return "Display size and text, switches"
        case .security: return "App lock, deletion protection"
        case .system: return "Gestures, time, backup, reset"
        }
    }

    var icon: String {
        switch self {
        case .apps: return "square.grid.3x3.fill"
        case .notifications: return "bell.fill"
        case .storage: return "line.3.horizontal"
        case .display: return "sun.max.fill"
        case .wallpaper: return "paintpalette.fill"
        case .accessibility: return "accessibility"
        case .security: return "lock.fill"
        case .system: return "info"
        }
    }

    /// colors.xml homepage_*_background.
    var color: UInt32 {
        switch self {
        case .apps, .notifications: return 0xFFFF7E0F
        case .storage: return 0xFFC14CE6
        case .display: return 0xFFFFA727
        case .wallpaper: return 0xFF1A73E8
        case .accessibility: return 0xFF5011C1
        case .security: return 0xFF0F9D58
        case .system: return 0xFF9E9E9E
        }
    }

    /// The screen a tile opens; nil hides it (Wallpaper without registered entries).
    @MainActor
    var route: Route? {
        switch self {
        case .apps: return .apps
        case .notifications: return .notifications
        case .storage: return .storage
        case .display: return .display
        case .wallpaper:
            let entries = SystemSettingsRegistry.entries(in: .wallpaper)
            if entries.count == 1 { return .entry(entries[0].id) }
            return entries.isEmpty ? nil : .category(rawValue)
        case .accessibility: return .accessibility
        case .security: return .security
        case .system: return .system
        }
    }
}

/// SettingsHomepageActivity: search bar and the top-level dashboard.
struct HomepageView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @State private var storageSummary = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { router.push(.search) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 18))
                        Text("Search Settings").font(.system(size: 16))
                        Spacer()
                    }
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Capsule().fill(palette.surface))
                }
                .buttonStyle(.plain)
                CloseAppButton()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(TopLevel.allCases) { item in
                        if let route = item.route {
                            Button { router.push(route) } label: {
                                HStack(spacing: 16) {
                                    HomepageIcon(symbol: item.icon, color: item.color)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.system(size: 17)).foregroundStyle(palette.textColor)
                                        let summary = item == .storage ? storageSummary : item.summary
                                        if !summary.isEmpty {
                                            Text(summary).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressedStyle())
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear {
            // TopLevelStoragePreferenceController: "%1$s used - %2$s free".
            if let v = Storage.volume(), v.total > 0 {
                let percent = Int((Double(v.used) / Double(v.total) * 100).rounded())
                storageSummary = "\(percent)% used - \(v.free.formattedSize) free"
            }
        }
    }
}
