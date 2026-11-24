import Foundation

/// Where a file lives in the shared sandbox.
enum SandboxDir {
    case documents, appSupport, caches, temporary

    var url: URL {
        let fm = FileManager.default
        switch self {
        case .documents: return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .appSupport: return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        case .caches: return fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        case .temporary: return fm.temporaryDirectory
        }
    }
}

/// The data one port keeps in the shared sandbox (all apps run in one process inside the
/// launcher): its private files, caches, UserDefaults suites and keys. User files in Documents
/// (photos, recordings, backups) are not app data, like Android's shared storage.
struct AppDataSpec {
    var data: [(SandboxDir, String)] = []
    var cache: [(SandboxDir, String)] = []
    var suites: [String] = []

    var keys: [String] { Self.generatedKeys[port]?.0 ?? [] }
    var keyPrefixes: [String] { Self.generatedKeys[port]?.1 ?? [] }
    let port: String

    /// Read from each port's sources (FileManager paths and `UserDefaults(suiteName:)`).
    static func of(_ port: String) -> AppDataSpec {
        var s = AppDataSpec(port: port)
        switch port {
        case "calendar-ios": s.data = [(.appSupport, "FossifyCalendar")]
        case "camera-ios": s.suites = ["org.fossify.camera"]; s.cache = [(.temporary, "camera-preview")]
        case "clock-ios": s.data = [(.appSupport, "Clock")]
        case "documents-ios": s.cache = [(.temporary, "docx")]
        case "file-manager-ios": s.cache = [(.temporary, "OpenAs")]
        case "gallery-ios": s.cache = [(.caches, "gallery_file_info.plist")]
        case "keyboard-ios": s.suites = ["group.org.fossify.keyboard.ios"]
        case "launcher-ios": s.data = [(.appSupport, "Launcher")]
        case "messages-ios": s.data = [(.appSupport, "Messages")]
        case "music-player-ios": s.data = [(.appSupport, "MusicPlayer")]; s.cache = [(.caches, "LibraryExport")]
        case "notes-ios": s.data = [(.appSupport, "Notes")]; s.suites = ["org.fossify.notes"]
        case "paint-ios": s.cache = [(.temporary, "images")]
        case "phone-ios": s.data = [(.appSupport, "phone_recent_calls.json")]
        default: break
        }
        return s
    }

    /// Whether Settings knows anything this app stores.
    var isKnown: Bool { !data.isEmpty || !cache.isEmpty || !suites.isEmpty || !keys.isEmpty || !keyPrefixes.isEmpty }

    // MARK: sizes

    struct Usage: Equatable {
        var data: Int64 = 0
        var cache: Int64 = 0
        var total: Int64 { data + cache }
    }

    func usage() -> Usage {
        var u = Usage()
        u.data = data.reduce(0) { $0 + Storage.size(of: $1.0.url.appendingPathComponent($1.1)) } + defaultsSize()
        u.cache = cache.reduce(0) { $0 + Storage.size(of: $1.0.url.appendingPathComponent($1.1)) }
        return u
    }

    /// Serialized size of the app's UserDefaults values.
    private func defaultsSize() -> Int64 {
        var values: [String: Any] = [:]
        let standard = UserDefaults.standard.dictionaryRepresentation()
        for (k, v) in standard where owns(k) { values[k] = v }
        for suite in suites {
            for (k, v) in DefaultsDomains.values(ofSuite: suite) { values["\(suite).\(k)"] = v }
        }
        guard !values.isEmpty,
              let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        else { return 0 }
        return Int64(data.count)
    }

    func owns(_ key: String) -> Bool {
        keys.contains(key) || keyPrefixes.contains { key.hasPrefix($0) }
    }

    // MARK: clearing

    func clearCache() {
        for (dir, path) in cache { Storage.removeContents(dir.url.appendingPathComponent(path)) }
    }

    /// Clear storage: private files, caches, suites and the app's keys.
    func clearData() {
        clearCache()
        for (dir, path) in data { try? FileManager.default.removeItem(at: dir.url.appendingPathComponent(path)) }
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where owns(k) { d.removeObject(forKey: k) }
        for suite in suites { DefaultsDomains.clear(suite: suite) }
    }
}
