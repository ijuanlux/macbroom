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
            AutomationTab()
                .tabItem { Label("Automation", systemImage: "bell.badge") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 340)
    }
}

private struct AutomationTab: View {
    @AppStorage("macbroom.autoDiskWatcher") private var autoDiskWatcher: Bool = false
    @AppStorage("macbroom.diskAlertThreshold") private var threshold: Double = 10

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $autoDiskWatcher) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch free disk space")
                        Text("Notify when free space falls below the threshold (checked every ~15 min while MacBroom is running).")
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
