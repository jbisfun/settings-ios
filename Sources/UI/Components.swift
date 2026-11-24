import FossifyCommons
import SwiftUI
import UIKit

/// A settings screen: Fossify top bar over a scrolling preference list.
struct PrefScreen<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: title)
            ScrollView {
                VStack(spacing: 0, content: content)
                    .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}

/// PreferenceCategory title.
struct PrefCategory: View {
    @Environment(\.palette) private var palette
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View { Text(title).sectionHeader(palette) }
}

/// Preference: optional icon, title and summary.
struct PrefRow<Trailing: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var summary: String?
    var icon: String?
    var action: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let row = HStack(spacing: 0) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(palette.primaryColor)
                    .frame(width: 40, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
                if let summary, !summary.isEmpty {
                    Text(summary).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.4)
        if let action {
            Button(action: action) { row }.buttonStyle(PressedStyle())
        } else {
            row
        }
    }
}

extension PrefRow where Trailing == EmptyView {
    init(_ title: String, summary: String? = nil, icon: String? = nil, action: (() -> Void)? = nil) {
        self.init(title: title, summary: summary, icon: icon, action: action, trailing: { EmptyView() })
    }
}

/// SwitchPreference with a summary line (commons SettingsToggle has none).
struct PrefSwitch: View {
    @Environment(\.palette) private var palette
    let title: String
    var summary: String?
    var icon: String?
    @Binding var isOn: Bool

    init(_ title: String, summary: String? = nil, icon: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.summary = summary
        self.icon = icon
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 0) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(palette.primaryColor)
                        .frame(width: 40, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
                    if let summary {
                        Text(summary).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                    }
                }
            }
        }
        .toggleStyle(CheckmarkSwitchStyle())
        .tint(palette.primaryColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// FooterPreference.
struct PrefFooter: View {
    @Environment(\.palette) private var palette
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "info.circle").font(.system(size: 18))
            Text(text).font(.system(size: 14))
        }
        .foregroundStyle(palette.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

/// Colored round icon of the homepage (HomepagePreference / AdaptiveIcon).
struct HomepageIcon: View {
    let symbol: String
    let color: UInt32

    var body: some View {
        Circle()
            .fill(Color(argb: color))
            .frame(width: 40, height: 40)
            .overlay(Image(systemName: symbol).font(.system(size: 19, weight: .medium)).foregroundStyle(.white))
    }
}

/// An app's launcher icon, or its AppInfo symbol on the primary color.
struct AppIcon: View {
    @Environment(\.palette) private var palette
    let app: SystemAppEntry
    var size: CGFloat = 40

    var body: some View {
        if let image = app.icon {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        } else {
            Circle().fill(palette.primaryColor).frame(width: size, height: size)
                .overlay(Image(systemName: app.info.icon).font(.system(size: size * 0.45)).foregroundStyle(palette.onPrimary))
        }
    }
}

/// The registered entries of a category, as rows.
struct EntryRows: View {
    @Environment(Router.self) private var router
    let category: SystemSettingsEntry.Category

    var body: some View {
        ForEach(SystemSettingsRegistry.entries(in: category)) { entry in
            PrefRow(entry.title, summary: entry.summary, icon: entry.icon) { router.push(.entry(entry.id)) }
        }
    }
}

/// Shows a registered entry's screen.
struct EntryHost: View {
    let entryID: String

    var body: some View {
        if let entry = SystemSettingsRegistry.entries.first(where: { $0.id == entryID }) {
            entry.destination()
        } else {
            PrefScreen(title: "Settings") { PrefFooter("This setting is not available.") }
        }
    }
}

/// Registered entries of a category without its own screen (e.g. Wallpaper with several entries).
struct CategoryEntriesView: View {
    let category: SystemSettingsEntry.Category

    var body: some View {
        PrefScreen(title: TopLevel(category: category)?.title ?? category.rawValue.capitalized) {
            EntryRows(category: category)
        }
    }
}

extension SystemAppEntry {
    /// The NotificationHub / AppNotifications id: the port without "-ios".
    var notificationID: String {
        info.port.hasSuffix("-ios") ? String(info.port.dropLast(4)) : info.port
    }
}

@MainActor
func registeredApp(_ id: String) -> SystemAppEntry? {
    SystemSettingsRegistry.apps.first { $0.id == id }
}
