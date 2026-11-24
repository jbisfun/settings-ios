import FossifyCommons
import SwiftUI
import UIKit

@MainActor
private var currentScreen: UIScreen {
    (UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene)?.screen ?? UIScreen.main
}

/// DisplaySettings (display_settings.xml).
struct DisplayView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @State private var config = BaseConfig.shared
    @State private var brightness = Double(currentScreen.brightness)
    @State private var keepScreenOn = SystemDisplay.keepScreenOn
    @State private var autoRotate = SystemDisplay.autoRotate
    @State private var pickTimeout = false

    var body: some View {
        PrefScreen(title: "Display") {
            PrefCategory("Brightness")
            VStack(alignment: .leading, spacing: 4) {
                Text("Brightness level").font(.system(size: 16))
                HStack(spacing: 12) {
                    Image(systemName: "sun.min").foregroundStyle(palette.secondaryText)
                    Slider(value: $brightness, in: 0...1)
                    Image(systemName: "sun.max").foregroundStyle(palette.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: brightness) { _, v in currentScreen.brightness = CGFloat(v) }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
                let v = Double(currentScreen.brightness)
                if abs(v - brightness) > 0.01 { brightness = v }
            }

            PrefCategory("Lock display")
            PrefRow("Screen timeout", summary: keepScreenOn ? "Never" : "Use the iOS Auto-Lock time") { pickTimeout = true }

            PrefCategory("Appearance")
            PrefSwitch("Dark theme", isOn: Binding(get: { palette.dark }, set: { config.theme = $0 ? .dark : .light }))
            PrefRow("Display size and text", summary: "Font size: \(config.fontSize.title)") { router.push(.textReading) }

            PrefCategory("Color")
            PrefRow("Colors", summary: config.theme.title) { router.push(.customizeColors) }

            PrefCategory("Other display controls")
            PrefSwitch("Auto-rotate screen", isOn: Binding(get: { autoRotate }, set: { v in
                autoRotate = v
                SystemDisplay.setAutoRotate(v)
            }))
            EntryRows(category: .display)
        }
        .sheet(isPresented: $pickTimeout) {
            RadioDialog(title: "Screen timeout", items: [(false, "Use the iOS Auto-Lock time"), (true, "Never")], selected: keepScreenOn) { v in
                keepScreenOn = v
                SystemDisplay.setKeepScreenOn(v)
            }
            .environment(\.palette, palette)
        }
    }
}

/// TextReadingPreferenceFragment ("Display size and text"): the Fossify font size.
struct TextReadingView: View {
    @Environment(\.palette) private var palette
    @State private var config = BaseConfig.shared

    var body: some View {
        PrefScreen(title: "Display size and text") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview").font(.system(size: 14, weight: .medium)).foregroundStyle(palette.secondaryText)
                Text("Fossify apps use this text size for their lists, notes and messages.")
                    .font(.system(size: config.fontSize.points))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(palette.surface))
            .padding(16)
            VStack(alignment: .leading, spacing: 4) {
                Text("Font size").font(.system(size: 16))
                Text(config.fontSize.title).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: Binding(get: { Double(config.fontSize.rawValue) },
                                          set: { config.fontSize = FontSize(rawValue: Int($0.rounded())) ?? .large }),
                           in: 0...Double(FontSize.allCases.count - 1), step: 1)
                    Image(systemName: "textformat.size.larger")
                }
                .foregroundStyle(palette.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            PrefFooter("Changes the text size inside every Fossify app. The size of iOS controls follows iOS Settings › Display & Brightness › Text Size.")
        }
    }
}

/// AccessibilitySettings (accessibility_settings.xml), Display + registered entries.
struct AccessibilityView: View {
    @Environment(Router.self) private var router
    @AppStorage(GlobalSettings.showCheckmarksOnSwitchesKey) private var checkmarks = false
    @State private var config = BaseConfig.shared

    var body: some View {
        PrefScreen(title: "Accessibility") {
            PrefCategory("Display")
            PrefRow("Display size and text", summary: "Font size: \(config.fontSize.title)", icon: "textformat.size") {
                router.push(.textReading)
            }
            PrefRow("Color and contrast", summary: config.theme.title, icon: "circle.lefthalf.filled") { router.push(.customizeColors) }
            PrefCategory("Interaction controls")
            PrefSwitch("Show checkmarks on switches", summary: "Tell switches apart without relying on color", icon: "checkmark.circle", isOn: $checkmarks)
            EntryRows(category: .accessibility)
        }
    }
}
