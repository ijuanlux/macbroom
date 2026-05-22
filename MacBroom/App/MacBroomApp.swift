import SwiftUI

@main
struct MacBroomApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("macbroom.theme") private var themeRaw: String = AppTheme.auto.rawValue
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @AppStorage("macbroom.autoDiskWatcher") private var autoDiskWatcher: Bool = false
    @AppStorage("macbroom.diskAlertThreshold") private var diskAlertThreshold: Double = 10

    init() {
        let defaults = UserDefaults.standard
        // Restore disk watcher from last session.
        if defaults.bool(forKey: "macbroom.autoDiskWatcher") {
            let thr = defaults.double(forKey: "macbroom.diskAlertThreshold")
            Task { @MainActor in
                AutomationScheduler.shared.startDiskWatcher(thresholdPercent: thr > 0 ? thr : 10)
            }
        }
        // Restore Smart Scan schedule.
        if let raw = defaults.string(forKey: "macbroom.scanFrequency"),
           let freq = SmartScanFrequency(rawValue: raw), freq != .off {
            let appStateLocal = self.appState
            Task { @MainActor in
                AutomationScheduler.shared.onScheduledSmartScan = {
                    let coord = SmartScanCoordinator()
                    await coord.scan()
                    let reclaimed = await coord.cleanAll()
                    if reclaimed > 0 {
                        appStateLocal.signalCleanup(reclaimed: reclaimed)
                    }
                    return reclaimed
                }
                AutomationScheduler.shared.startSmartScanSchedule(freq)
            }
        }
        // Restore menu-bar-only mode (if previously enabled).
        if defaults.bool(forKey: "macbroom.menuBarOnly") {
            Task { @MainActor in
                DockVisibility.setShown(false)
            }
        }
        // Snapshot disk space for the forecast trend.
        Task { @MainActor in
            DiskTrendStore.shared.snapshotIfNeeded()
        }
    }

    private var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .auto
    }

    private var hackerGreen: Color { Color(red: 0.20, green: 0.95, blue: 0.35) }

    var body: some Scene {
        mainWindow
            .windowResizability(.contentMinSize)
            .commands {
                CommandGroup(replacing: .newItem) { }
                CommandMenu("Actions") {
                    Button("Command Palette") {
                        appState.paletteVisible = true
                    }
                    .keyboardShortcut("k", modifiers: .command)
                }
            }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.original)
                .resizable()
                .frame(width: 22, height: 22)
        }
        .menuBarExtraStyle(.window)
    }

    private var mainWindow: some Scene {
        WindowGroup {
            rootContent
        }
    }

    private var rootContent: some View {
        RootView()
            .environmentObject(appState)
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(hackerMode ? .dark : theme.colorScheme)
            .tint(hackerMode ? hackerGreen : .accentColor)
            .fontDesign(hackerMode ? .monospaced : .default)
            .onOpenURL { url in
                // Drag a folder onto the Dock icon → jump straight to Disk Explorer in that folder.
                guard url.isFileURL,
                      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
                appState.selection = .explorer
                appState.requestedExplorerURL = url
            }
    }
}

private struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @AppStorage("macbroom.onboardingShown") private var onboardingShown: Bool = false
    @State private var confettiFire: Bool = false
    @State private var toastVisible: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            if hackerMode {
                Color.black.ignoresSafeArea()
                MatrixRain()
                    .opacity(0.12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ContentView()
                .background(hackerMode ? Color.clear : Color(nsColor: .windowBackgroundColor))

            ConfettiBurst(fire: $confettiFire)
                .allowsHitTesting(false)

            if toastVisible {
                CleanupToast(reclaimed: appState.lastReclaimed)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !appState.splashDismissed {
                SplashScreen { appState.splashDismissed = true }
                    .transition(.opacity)
            }

            if appState.splashDismissed && !onboardingShown {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.4)) { onboardingShown = true }
                }
                .transition(.opacity)
                .zIndex(50)
            }

            if appState.paletteVisible {
                CommandPalette(
                    isPresented: $appState.paletteVisible,
                    actions: paletteActions
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(100)
            }
        }
        .onChange(of: appState.cleanupTrigger) { _, _ in
            confettiFire.toggle()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                toastVisible = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeOut(duration: 0.35)) {
                    toastVisible = false
                }
            }
        }
    }

    private var paletteActions: [PaletteAction] {
        var actions: [PaletteAction] = SidebarItem.allCases.map { item in
            PaletteAction(
                title: "Go to \(item.title)",
                subtitle: "Open the \(item.title.lowercased()) section",
                systemImage: item.systemImage,
                tint: item.tint,
                perform: { appState.selection = item }
            )
        }
        actions.append(PaletteAction(
            title: hackerMode ? "Disable hacker theme" : "Enable hacker theme",
            subtitle: "Toggle the green Matrix UI everywhere",
            systemImage: "terminal.fill",
            tint: Color(red: 0.20, green: 0.95, blue: 0.35),
            perform: { hackerMode.toggle() }
        ))
        actions.append(PaletteAction(
            title: "Open Settings",
            subtitle: "Preferences and Hacker theme toggle",
            systemImage: "gearshape",
            tint: .gray,
            perform: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        ))
        actions.append(PaletteAction(
            title: "Quit MacBroom",
            subtitle: "Close the app",
            systemImage: "power",
            tint: Theme.stripeRed,
            perform: { NSApplication.shared.terminate(nil) }
        ))
        return actions
    }
}

private struct CleanupToast: View {
    let reclaimed: Int64

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reclaimed \(FileSystemUtils.formatBytes(reclaimed))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Moved to Trash — restore from there if needed")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearGradient(colors: Theme.rainbow,
                                     startPoint: .leading,
                                     endPoint: .trailing))
                .opacity(0.95)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}
