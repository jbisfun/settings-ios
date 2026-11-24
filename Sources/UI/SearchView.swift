import FossifyCommons
import SwiftUI

/// One searchable setting (SettingsSearchIndexablesProvider / SearchIndexableRaw).
struct SearchItem: Identifiable {
    let id: String
    let title: String
    /// "Display > Appearance"-style path shown under the title.
    let breadcrumb: String
    var keywords: [String] = []
    let route: Route
    var icon: String = "gearshape"
}

@MainActor
enum SearchIndex {
    static func all() -> [SearchItem] {
        var items: [SearchItem] = []
        func add(_ title: String, _ crumb: String, _ route: Route, _ keywords: [String] = []) {
            items.append(SearchItem(id: "\(crumb)/\(title)", title: title, breadcrumb: crumb, keywords: keywords, route: route,
                                    icon: TopLevel.allCases.first { crumb.hasPrefix($0.title) }?.icon ?? "gearshape"))
        }
        for top in TopLevel.allCases {
            if let route = top.route { add(top.title, "Settings", route, [top.summary]) }
        }
        // Apps
        if !SystemSettingsRegistry.apps.isEmpty { add("All apps", "Apps", .allApps(bySize: false), ["app info", "installed"]) }
        for app in SystemSettingsRegistry.apps {
            add(app.info.name, "Apps", .appInfo(app.id), ["app info", "storage", "clear data", "cache", app.info.upstream])
            if sendsNotifications(app) { add("\(app.info.name) notifications", "Notifications", .appNotifications(app.id), ["block"]) }
        }
        // Notifications
        add("App notifications", "Notifications", .notifications, ["block", "allow", "alerts"])
        add("Notification permission", "Notifications", .notifications, ["ios settings", "allow"])
        // Storage
        add("Free up space", "Storage", .storage, ["cache", "clean", "temporary files"])
        add("Use binary storage units", "Storage", .storage, ["kib", "mib", "units"])
        // Display
        add("Brightness level", "Display > Brightness", .display, ["screen", "dim", "bright"])
        add("Screen timeout", "Display > Lock display", .display, ["keep screen on", "sleep", "auto-lock", "awake"])
        add("Dark theme", "Display > Appearance", .display, ["night", "dark mode", "light"])
        add("Display size and text", "Display > Appearance", .textReading, ["font size", "text size", "bigger"])
        add("Font size", "Display > Display size and text", .textReading, ["text", "bigger", "smaller"])
        add("Colors", "Display > Color", .customizeColors, ["theme", "text color", "background color", "primary color", "customize"])
        add("Auto-rotate screen", "Display > Other display controls", .display, ["rotation", "portrait", "landscape", "orientation"])
        // Accessibility
        add("Show checkmarks on switches", "Accessibility > Interaction controls", .accessibility, ["toggle", "color blind"])
        // Security
        add("App lock", "Security & privacy", .security, ["password", "pin", "pattern", "face id", "touch id", "protect"])
        add("Lock after", "Security & privacy", .security, ["timeout", "auto lock"])
        add("Protect deletion", "Security & privacy", .security, ["password", "delete", "move"])
        // System
        add("Date & time", "System", .dateTime, ["clock", "format"])
        add("Use 24-hour format", "System > Date & time", .dateTime, ["24h", "am", "pm", "time format"])
        add("Date format", "System > Date & time", .dateTime, ["day", "month", "year"])
        add("Backup", "System", .backup, ["restore"])
        add("Export settings", "System > Backup", .backup, ["save", "file"])
        add("Import settings", "System > Backup", .backup, ["restore", "file"])
        add("Reset options", "System", .reset, ["reset"])
        add("Reset app preferences", "System > Reset options", .reset, ["notifications", "defaults"])
        add("Erase all data (factory reset)", "System > Reset options", .reset, ["erase", "delete", "wipe", "factory"])
        // Registered entries
        for entry in SystemSettingsRegistry.entries {
            let crumb = TopLevel(category: entry.category)?.title ?? entry.category.rawValue.capitalized
            items.append(SearchItem(id: "entry/\(entry.id)", title: entry.title, breadcrumb: crumb,
                                    keywords: entry.keywords + [entry.summary ?? ""], route: .entry(entry.id), icon: entry.icon))
        }
        return items
    }

    static func search(_ query: String) -> [SearchItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        func rank(_ item: SearchItem) -> Int? {
            let t = item.title.lowercased()
            if t.hasPrefix(q) { return 0 }
            if t.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 1 }
            if t.contains(q) { return 2 }
            if item.keywords.contains(where: { $0.lowercased().contains(q) }) { return 3 }
            return nil
        }
        var ranked: [(item: SearchItem, rank: Int)] = []
        for item in all() {
            if let r = rank(item) { ranked.append((item, r)) }
        }
        ranked.sort { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.item.title < b.item.title
        }
        return ranked.map { $0.item }
    }
}

/// SearchFragment: the homepage search across every setting.
struct SearchView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        let results = SearchIndex.search(query)
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                IconButton(icon: "arrow.left") { dismiss() }
                TextField("Search Settings", text: $query)
                    .font(.system(size: 17))
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty { IconButton(icon: "xmark") { query = "" } }
            }
            .padding(.horizontal, 4)
            .frame(height: 56)
            .background(Capsule().fill(palette.surface).padding(.horizontal, 8).padding(.vertical, 4))
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !query.isEmpty && results.isEmpty {
                        Text("No results").foregroundStyle(palette.secondaryText).padding(32)
                    }
                    ForEach(results) { item in
                        PrefRow(item.title, summary: item.breadcrumb, icon: item.icon) { router.push(item.route) }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { focused = true }
    }
}
