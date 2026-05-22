import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:  return "System"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            SafetyTab()
                .tabItem { Label("Safety", systemImage: "lock.shield") }
            AutomationTab()
                .tabItem { Label("Automation", systemImage: "bell.badge") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 380)
    }
}

private struct SafetyTab: View {
    @ObservedObject private var prefs = SafetyPreferences.shared
    @State private var selection: String?

    var body: some View {
        Form {
            Section {
                Picker("Auto-select profile", selection: $prefs.profile) {
                    ForEach(SafetyProfile.allCases) { profile in
                        Text(profile.label).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                Text(prefs.profile.blurb)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Safety profile")
            } footer: {
                Text("Controls what gets auto-selected when you press Select all in any scanner.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                if prefs.excludedPaths.isEmpty {
                    Text("No excluded paths. Add folders MacBroom should never touch.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List(selection: $selection) {
                        ForEach(prefs.excludedPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(SidebarItem.privacy.tint)
                                Text(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.system(size: 12, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .tag(path)
                        }
                    }
                    .frame(minHeight: 100, maxHeight: 160)
                }
                HStack {
                    Button("Add folder…") { addFolder() }
                    Button("Remove") {
                        if let selection { prefs.removeExcluded(selection) }
                        selection = nil
                    }
                    .disabled(selection == nil)
                    Spacer()
                }
            } header: {
                Text("Excluded paths")
            } footer: {
                Text("Folders here are never touched by any scanner. Useful for critical project directories you don't want to risk.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder MacBroom should never touch"
        panel.prompt = "Exclude"
        if panel.runModal() == .OK, let url = panel.url {
            prefs.addExcluded(url.path)
        }
    }
}

private struct AutomationTab: View {
    @AppStorage("macbroom.autoDiskWatcher") private var autoDiskWatcher: Bool = false
    @AppStorage("macbroom.diskAlertThreshold") private var threshold: Double = 10
    @AppStorage("macbroom.scanFrequency") private var scanFrequencyRaw: String = SmartScanFrequency.off.rawValue

    private var scanFrequency: Binding<SmartScanFrequency> {
        Binding(
            get: { SmartScanFrequency(rawValue: scanFrequencyRaw) ?? .off },
            set: { scanFrequencyRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Run Smart Scan", selection: scanFrequency) {
                    ForEach(SmartScanFrequency.allCases) { freq in
                        Text(freq.label).tag(freq)
                    }
                }
                .onChange(of: scanFrequencyRaw) { _, _ in
                    let freq = SmartScanFrequency(rawValue: scanFrequencyRaw) ?? .off
                    Task {
                        await NotificationManager.shared.requestAuthorizationIfNeeded()
                        AutomationScheduler.shared.startSmartScanSchedule(freq)
                    }
                }
            } header: {
                Text("Smart Scan schedule")
            } footer: {
                Text("Runs in the background and posts a notification with how much space was reclaimed. Only fires while MacBroom is running.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $autoDiskWatcher) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch free disk space")
                        Text("Notify when free space falls below the threshold (checked every ~15 min).")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: autoDiskWatcher) { _, enabled in
                    if enabled {
                        Task {
                            await NotificationManager.shared.requestAuthorizationIfNeeded()
                            AutomationScheduler.shared.startDiskWatcher(thresholdPercent: threshold)
                        }
                    } else {
                        AutomationScheduler.shared.stop()
                    }
                }

                HStack {
                    Text("Alert when free is below")
                    Spacer()
                    Text("\(Int(threshold))%")
                        .font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $threshold, in: 5...30, step: 5)
                    .disabled(!autoDiskWatcher)
                    .onChange(of: threshold) { _, newValue in
                        if autoDiskWatcher {
                            AutomationScheduler.shared.startDiskWatcher(thresholdPercent: newValue)
                        }
                    }
            } header: {
                Text("Disk space alerts")
            }

            Section {
                Button("Send test notification") {
                    Task {
                        await NotificationManager.shared.requestAuthorizationIfNeeded()
                        NotificationManager.shared.post(
                            title: "MacBroom is alive",
                            body: "Notifications are working. Smart Scan when you want."
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralTab: View {
    @AppStorage("macbroom.theme") private var themeRaw: String = AppTheme.auto.rawValue
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @AppStorage("macbroom.minSizeMB") private var minSizeMB: Int = 0
    @AppStorage("macbroom.showSystemCaches") private var showSystemCaches: Bool = true
    @AppStorage("macbroom.launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("macbroom.menuBarOnly") private var menuBarOnly: Bool = false
    @AppStorage("macbroom.soundEffects") private var soundEffects: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(hackerMode)

                Toggle(isOn: $hackerMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal.fill")
                                .foregroundStyle(Color(red: 0.20, green: 0.95, blue: 0.35))
                            Text("Hacker theme")
                        }
                        Text("Matrix vibes everywhere — green accents, dark surfaces, glow effects")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                        Text("MacBroom starts automatically when you log in to macOS.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { _, newValue in
                    let success = LaunchAtLogin.setEnabled(newValue)
                    if !success { launchAtLogin = LaunchAtLogin.isEnabled }
                }

                Toggle(isOn: $menuBarOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu bar only (hide Dock icon)")
                        Text("Lives quietly in the menu bar. Click the icon to bring up the panel; the main window opens on demand.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: menuBarOnly) { _, newValue in
                    DockVisibility.setShown(!newValue)
                }
            } header: {
                Text("Startup & presence")
            }

            Section {
                Stepper(value: $minSizeMB, in: 0...1024) {
                    Text("Hide items smaller than \(minSizeMB) MB")
                }
                Toggle("Show com.apple.* system caches", isOn: $showSystemCaches)
            } header: {
                Text("Scanners")
            } footer: {
                Text("Tip: hiding system caches and tiny items makes results easier to act on.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Play a sound when cleanup completes", isOn: $soundEffects)
            } header: {
                Text("Feedback")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            AppIconView(size: 96)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

            VStack(spacing: 4) {
                Text("MacBroom")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.rainbow)
                Text("Version 0.1 — released for the community")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("A retro-inspired Mac cleaner that sweeps caches, developer junk, and apps with their leftovers in one click.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()
        }
        .padding(.top, 20)
    }
}
