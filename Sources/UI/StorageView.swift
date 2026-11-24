import FossifyCommons
import SwiftUI

/// StorageDashboardFragment (storage_dashboard_fragment.xml) for the Fossify sandbox.
struct StorageView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @AppStorage(GlobalSettings.useBinaryStorageUnitsKey) private var binaryUnits = false
    @State private var volume = Storage.volume()
    @State private var summary: Storage.Summary?
    @State private var freeing = false

    var body: some View {
        PrefScreen(title: "Storage") {
            if let volume {
                usageHeader(volume)
            }
            freeUpSpaceCard
            if let summary {
                let maxSize = max(1, ([summary.appsTotal, summary.cachesAndTemp, summary.settings] + Array(summary.kinds.values)).max() ?? 1)
                item("Apps", icon: "square.grid.2x2", size: summary.appsTotal, max: maxSize) {
                    router.push(.allApps(bySize: true))
                }
                .disabled(SystemSettingsRegistry.apps.isEmpty)
                ForEach(Storage.Kind.allCases, id: \.self) { kind in
                    item(kind.rawValue, icon: kind.icon, size: summary.kinds[kind] ?? 0, max: maxSize)
                }
                item("Settings", icon: "gearshape", size: summary.settings, max: maxSize)
                item("Temporary files", icon: "clock.arrow.circlepath", size: summary.cachesAndTemp, max: maxSize)
                if !summary.folders.isEmpty {
                    PrefCategory("Files")
                    ForEach(summary.folders, id: \.name) { f in
                        PrefRow(f.name, summary: f.size.formattedSize, icon: "folder")
                    }
                }
            } else {
                ProgressView().padding(32)
            }
            PrefCategory("Units")
            PrefSwitch("Use binary storage units", summary: binaryUnits ? "1 KiB = 1024 bytes" : "1 kB = 1000 bytes", isOn: $binaryUnits)
            EntryRows(category: .storage)
        }
        .task { await rescan() }
        .id(binaryUnits)
    }

    private func usageHeader(_ v: Storage.Volume) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(v.used.formattedSize).font(.system(size: 36, weight: .regular))
                Text("used").font(.system(size: 16)).foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(v.total.formattedSize) total").font(.system(size: 14)).foregroundStyle(palette.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.divider)
                    Capsule().fill(palette.primaryColor)
                        .frame(width: geo.size.width * CGFloat(v.total > 0 ? Double(v.used) / Double(v.total) : 0))
                }
            }
            .frame(height: 8)
            Text("\(v.free.formattedSize) free").font(.system(size: 14)).foregroundStyle(palette.secondaryText)
        }
        .padding(16)
    }

    private var freeUpSpaceCard: some View {
        Button {
            freeing = true
            Task {
                let freed = await Task.detached { Storage.freeUpSpace() }.value
                freeing = false
                router.toast = "\(freed.formattedSize) freed"
                await rescan()
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(palette.primaryColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free up space").font(.system(size: 16, weight: .medium))
                    Text("Clear the caches and temporary files of every Fossify app"
                         + (summary.map { " (\($0.cachesAndTemp.formattedSize))" } ?? ""))
                        .font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                }
                Spacer()
                if freeing { ProgressView() }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(palette.surface))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .buttonStyle(PressedStyle())
        .disabled(freeing)
    }

    /// StorageItemPreference: title, size and a proportional bar.
    private func item(_ title: String, icon: String, size: Int64, max: Int64, action: (() -> Void)? = nil) -> some View {
        PrefRow(title: title, summary: nil, icon: icon, action: action) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(size.formattedSize).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.divider)
                        Capsule().fill(palette.primaryColor).frame(width: geo.size.width * CGFloat(Double(size) / Double(max)))
                    }
                }
                .frame(width: 96, height: 4)
            }
        }
    }

    private func rescan() async {
        volume = Storage.volume()
        let ports = SystemSettingsRegistry.apps.map(\.id)
        summary = await Task.detached { Storage.scan(ports: ports) }.value
    }
}
