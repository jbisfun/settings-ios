import Foundation
import UniformTypeIdentifiers

/// File sizes and the device storage figures of the Storage screen.
enum Storage {
    /// Allocated size of a file or folder (recursively), 0 if missing.
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let v = try? url.resourceValues(forKeys: keys) else { return 0 }
        if v.isDirectory != true { return fileSize(v) }
        var total: Int64 = 0
        let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: nil)
        while let child = e?.nextObject() as? URL {
            if let cv = try? child.resourceValues(forKeys: keys), cv.isDirectory != true { total += fileSize(cv) }
        }
        return total
    }

    private static func fileSize(_ v: URLResourceValues) -> Int64 {
        Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? v.fileSize ?? 0)
    }

    /// Deletes a file, or everything inside a folder (keeping the folder).
    static func removeContents(_ url: URL) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            for child in (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [] {
                try? fm.removeItem(at: child)
            }
        } else {
            try? fm.removeItem(at: url)
        }
    }

    struct Volume {
        var total: Int64
        var free: Int64
        var used: Int64 { max(0, total - free) }
    }

    static func volume() -> Volume? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let v = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = v.volumeTotalCapacity else { return nil }
        return Volume(total: Int64(total), free: v.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    /// StorageItemPreference categories.
    enum Kind: String, CaseIterable {
        case images = "Images", videos = "Videos", audio = "Audio", documents = "Documents", other = "Other"

        var icon: String {
            switch self {
            case .images: return "photo"
            case .videos: return "film"
            case .audio: return "music.note"
            case .documents: return "doc.text"
            case .other: return "folder"
            }
        }

        static func of(_ url: URL) -> Kind {
            guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
            if type.conforms(to: .image) { return .images }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .videos }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .text) || type.conforms(to: .pdf) || type.conforms(to: .presentation)
                || type.conforms(to: .spreadsheet) || type.conforms(to: .compositeContent) { return .documents }
            return .other
        }
    }

    struct Summary {
        var kinds: [Kind: Int64] = [:]
        /// Top-level folders/files in Documents (Files › On My iPhone › Fossify).
        var folders: [(name: String, size: Int64)] = []
        var apps: [String: AppDataSpec.Usage] = [:]
        var cachesAndTemp: Int64 = 0
        var settings: Int64 = 0

        var appsTotal: Int64 { apps.values.reduce(0) { $0 + $1.data } }
    }

    /// Walks the sandbox; call off the main thread.
    static func scan(ports: [String]) -> Summary {
        var s = Summary()
        let fm = FileManager.default
        let docs = SandboxDir.documents.url
        for child in (try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? [] {
            s.folders.append((child.lastPathComponent, size(of: child)))
        }
        s.folders.sort { $0.size > $1.size }
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
        let e = fm.enumerator(at: docs, includingPropertiesForKeys: keys, options: [], errorHandler: nil)
        while let url = e?.nextObject() as? URL {
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isDirectory != true else { continue }
            s.kinds[Kind.of(url), default: 0] += fileSize(v)
        }
        for port in ports { s.apps[port] = AppDataSpec.of(port).usage() }
        s.cachesAndTemp = size(of: SandboxDir.caches.url) + size(of: SandboxDir.temporary.url)
        let prefs = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Preferences")
        s.settings = size(of: prefs)
        return s
    }

    /// Free up space: empties Caches and tmp (every app's caches, thumbnails, exports).
    static func freeUpSpace() -> Int64 {
        let before = size(of: SandboxDir.caches.url) + size(of: SandboxDir.temporary.url)
        removeContents(SandboxDir.caches.url)
        removeContents(SandboxDir.temporary.url)
        let after = size(of: SandboxDir.caches.url) + size(of: SandboxDir.temporary.url)
        return max(0, before - after)
    }
}
