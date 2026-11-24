# settings-ios

[AOSP Settings](https://android.googlesource.com/platform/packages/apps/Settings) forked for iOS in SwiftUI, in the Fossify style (FossifyCommons), for the Fossify apps bundled in [launcher-ios](https://github.com/jbisfun/launcher-ios).

    idl build -c release     # -> build/release/FossifySettings.ipa (ad-hoc signed; re-sign to install)
    idl install "<device>" FossifySettings

Ported: the homepage (search bar, colored category icons, AOSP titles and summaries) and search across every setting; only the settings that Settings can change are kept. **Apps**: all apps, App info (open, clear cache, notifications, storage & cache with clear storage, additional settings in the app), plus the launcher's app entries (default/hidden apps). **Notifications**: per-app switches (honored by commons `NotificationHub`) and the iOS notification permission. **Storage**: used/free, free up space (every app's caches), usage by app, type (images, videos, audio, documents) and folder, binary units. **Display**: brightness level, screen timeout (keep screen on), dark theme, colors, display size and text (Fossify font size), auto-rotate, plus the launcher's display/wallpaper entries. **Accessibility**: display size and text, colors, checkmarks on switches. **Security & privacy**: the shared app lock (pattern/PIN/biometrics) and when it locks, deletion protection. **System**: launcher entries (gestures/navigation, ...), date & time (24-hour, date format), backup (export/import every app's settings), reset options (reset app preferences, erase all data). Settings registered through commons `SystemSettingsRegistry` appear in their category and in search.

Differences forced by iOS: the standalone app only sees its own process, so apps and launcher entries appear inside launcher-ios only; network, Bluetooth, battery, sound, location, accounts, languages and About are left out because iOS doesn't let an app change them; screen timeout can only be "never", per-app data is found from each port's known files and keys (`scripts/gen_app_keys.py`), and clearing data or importing settings fully applies once Fossify restarts.

Apache-2.0 (AOSP Settings) / GPL-3.0 (Fossify).
