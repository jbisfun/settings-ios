import FossifyCommons
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The UserDefaults domains the ports use: the app's own (shared by every port in the launcher)
/// plus the suites some ports keep (`UserDefaults(suiteName:)`).
enum DefaultsDomains {
    static var standardName: String { Bundle.main.bundleIdentifier ?? "standard" }

    static let knownSuites = ["org.fossify.camera", "org.fossify.notes", "group.org.fossify.keyboard.ios"]

    /// Known suites plus any other plist in Library/Preferences (ports added later).
    static func suites() -> [String] {
        let prefs = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Preferences")
        let found = ((try? FileManager.default.contentsOfDirectory(atPath: prefs.path)) ?? [])
            .filter { $0.hasSuffix(".plist") }
            .map { String($0.dropLast(6)) }
            .filter { $0 != standardName && !$0.hasPrefix("com.apple.") && !$0.hasPrefix(".") }
        return Array(Set(knownSuites + found)).sorted()
    }

    static func values(ofSuite suite: String) -> [String: Any] {
        if let d = UserDefaults.standard.persistentDomain(forName: suite), !d.isEmpty { return d }
        guard let suiteDefaults = UserDefaults(suiteName: suite) else { return [:] }
        // App-group suites aren't reachable as persistent domains: drop the inherited global keys.
        let inherited = Set(UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?.keys.map { $0 } ?? [])
            .union(UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain).keys)
            .union(UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain).keys)
        return suiteDefaults.dictionaryRepresentation().filter { !inherited.contains($0.key) && !$0.key.hasPrefix("Apple") && !$0.key.hasPrefix("NS") }
    }

    static func standardValues() -> [String: Any] {
        UserDefaults.standard.persistentDomain(forName: standardName) ?? [:]
    }

    static func clear(suite: String) {
        let keys = values(ofSuite: suite).keys
        UserDefaults.standard.removePersistentDomain(forName: suite)
        if let d = UserDefaults(suiteName: suite) { for k in keys { d.removeObject(forKey: k) } }
    }

    static func clearStandard() {
        UserDefaults.standard.removePersistentDomain(forName: standardName)
    }

    // MARK: backup

    /// Every Fossify setting, `[domain: [key: value]]`, as an XML property list.
    static func exportData() throws -> Data {
        var domains: [String: Any] = [standardName: standardValues()]
        for suite in suites() {
            let v = values(ofSuite: suite)
            if !v.isEmpty { domains[suite] = v }
        }
        let root: [String: Any] = ["format": "fossify-settings-1", "standard": standardName, "domains": domains]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }

    /// Restores an export; returns how many values were written.
    @discardableResult
    static func importData(_ data: Data) throws -> Int {
        guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              root["format"] as? String == "fossify-settings-1",
              let domains = root["domains"] as? [String: [String: Any]]
        else { throw CocoaError(.fileReadCorruptFile) }
        let exportedStandard = root["standard"] as? String
        var count = 0
        for (name, values) in domains {
            let target = name == exportedStandard ? UserDefaults.standard : (UserDefaults(suiteName: name) ?? .standard)
            for (k, v) in values {
                target.set(v, forKey: k)
                count += 1
            }
        }
        return count
    }
}

/// The backup file for `.fileExporter`.
struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.propertyList, .xml, .data] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Reset options.
@MainActor
enum Resets {
    /// Reset app preferences: notification blocks and the device-wide display/rotation settings.
    /// App data is kept.
    static func resetAppPreferences() {
        AppNotifications.enableAll()
        SystemDisplay.setKeepScreenOn(false)
        SystemDisplay.setAutoRotate(true)
    }

    /// Erase all data: every port's files, caches and settings.
    static func eraseAll() {
        for dir in [SandboxDir.documents, .appSupport, .caches, .temporary] { Storage.removeContents(dir.url) }
        for suite in DefaultsDomains.suites() { DefaultsDomains.clear(suite: suite) }
        DefaultsDomains.clearStandard()
        UserDefaults.standard.synchronize()
    }
}
