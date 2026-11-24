import FossifyCommons
import SwiftUI

/// SecuritySettings / privacy, for what Fossify can lock: the shared app lock and deletion lock.
struct SecurityView: View {
    @Environment(\.palette) private var palette
    @State private var security = SecurityConfig.shared
    @State private var pickTimeout = false

    private static let timeouts: [(Double, String)] = [
        (0, "Immediately"), (5_000, "5 seconds"), (30_000, "30 seconds"), (60_000, "1 minute"),
        (300_000, "5 minutes"), (900_000, "15 minutes"), (1_800_000, "30 minutes"),
    ]

    var body: some View {
        PrefScreen(title: "Security & privacy") {
            PrefCategory("App security")
            PasswordProtectionToggle("App lock", kind: .app)
            PrefRow("Lock after", summary: lockAfterSummary) { pickTimeout = true }
                .disabled(!security.isAppPasswordProtectionOn)
            PrefFooter("App lock asks for a pattern, PIN or Face ID / Touch ID when Settings, File Manager, Gallery, Messages or Notes opens.")
            PrefCategory("Deletion")
            PasswordProtectionToggle("Protect deletion", kind: .delete)
            PrefFooter("Asks for a password before File Manager, Gallery or Notes deletes or moves anything.")
            EntryRows(category: .security)
        }
        .sheet(isPresented: $pickTimeout) {
            RadioDialog(title: "Lock after", items: Self.timeouts, selected: nearestTimeout) { security.unlockTimeoutDurationMs = $0 }
                .environment(\.palette, palette)
        }
    }

    private var nearestTimeout: Double {
        Self.timeouts.min { abs($0.0 - security.unlockTimeoutDurationMs) < abs($1.0 - security.unlockTimeoutDurationMs) }?.0 ?? 30_000
    }

    private var lockAfterSummary: String {
        let label = Self.timeouts.first { $0.0 == nearestTimeout }?.1 ?? ""
        return nearestTimeout == 0 ? "Immediately after leaving the app" : "\(label) after leaving the app"
    }
}

/// SystemDashboardFragment (system_dashboard_fragment.xml).
struct SystemView: View {
    @Environment(Router.self) private var router
    @State private var dateTime = DateTimeFormat.shared

    var body: some View {
        PrefScreen(title: "System") {
            EntryRows(category: .system)
            PrefRow("Date & time", summary: DateTimeFormat.format(Date(), "\(dateTime.dateFormat), \(dateTime.timeFormat)"), icon: "clock") {
                router.push(.dateTime)
            }
            PrefRow("Backup", summary: "Export or import the settings of every Fossify app", icon: "arrow.clockwise.icloud") {
                router.push(.backup)
            }
            PrefRow("Reset options", icon: "arrow.counterclockwise") { router.push(.reset) }
        }
    }
}

/// DateTimeSettings (date_time_prefs.xml), with Fossify's shared date format.
struct DateTimeView: View {
    @Environment(\.palette) private var palette
    @State private var config = DateTimeFormat.shared

    /// February 15, 2023, 13:00, like ChangeDateTimeFormatDialog.
    private static let sample = Date(timeIntervalSince1970: 1_676_466_000)

    var body: some View {
        PrefScreen(title: "Date & time") {
            PrefCategory("Time format")
            PrefSwitch("Use 24-hour format", summary: DateTimeFormat.format(Self.sample, config.timeFormat), isOn: $config.use24HourFormat)
            PrefCategory("Date format")
            ForEach(DateTimeFormat.dateFormats, id: \.self) { format in
                Button { config.dateFormat = format } label: {
                    RadioRow(title: DateTimeFormat.format(Self.sample, format), on: format == config.dateFormat)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
            PrefFooter("Used by every Fossify app. The device clock and time zone are set in iOS Settings.")
        }
    }
}

/// Backup: export / import every Fossify app's settings.
struct BackupView: View {
    @Environment(Router.self) private var router
    @State private var exportDoc: SettingsBackupDocument?
    @State private var importing = false

    var body: some View {
        PrefScreen(title: "Backup") {
            PrefRow("Export settings", summary: "Save the settings of every Fossify app to a file", icon: "square.and.arrow.up") {
                do { exportDoc = SettingsBackupDocument(data: try DefaultsDomains.exportData()) } catch { router.toast = "An error occurred: \(error.localizedDescription)" }
            }
            PrefRow("Import settings", summary: "Restore settings from an exported file", icon: "square.and.arrow.down") { importing = true }
            PrefFooter("Backs up preferences (colors, app settings, launcher layout settings), not your notes, events or other files.")
        }
        .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                      document: exportDoc, contentType: .propertyList,
                      defaultFilename: "Fossify-settings_\(AutoBackup.currentFormattedDateTime())") { result in
            if case .success = result { router.toast = "Settings exported successfully" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .xml, .data]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let count = try DefaultsDomains.importData(try Data(contentsOf: url))
                router.restartMessage = "\(count) settings imported"
            } catch {
                router.toast = "Invalid file format"
            }
        }
    }
}

/// ResetDashboardFragment (reset_dashboard_fragment.xml).
struct ResetView: View {
    @Environment(Router.self) private var router
    @State private var confirmPrefs = false
    @State private var confirmErase = false
    @State private var check: SecurityCheck?

    var body: some View {
        PrefScreen(title: "Reset options") {
            PrefRow("Reset app preferences") { confirmPrefs = true }
            PrefRow("Erase all data (factory reset)", summary: "Every Fossify app's files and settings") {
                let security = SecurityConfig.shared
                if security.isAppPasswordProtectionOn {
                    check = SecurityCheck(protectionType: security.appProtectionType, requiredHash: security.appPasswordHash) { _, _ in
                        confirmErase = true
                    }
                } else {
                    confirmErase = true
                }
            }
        }
        .securityCheck($check)
        .alert("Reset app preferences?", isPresented: $confirmPrefs) {
            Button("Cancel", role: .cancel) {}
            Button("Reset apps", role: .destructive) {
                Resets.resetAppPreferences()
                router.toast = "App preferences reset"
            }
        } message: {
            Text("This will reset all preferences for:\n\nDisabled app notifications\nScreen timeout\nAuto-rotate screen\n\nYou will not lose any app data.")
        }
        .alert("Erase all data?", isPresented: $confirmErase) {
            Button("Cancel", role: .cancel) {}
            Button("Erase all data", role: .destructive) {
                Resets.eraseAll()
                router.restartMessage = "All data erased"
            }
        } message: {
            Text("All of the Fossify apps' files (notes, events, recordings, photos saved in Files), settings and caches will be deleted. Contacts, photos and music in your iOS libraries are kept. You can’t undo this action.")
        }
    }
}
