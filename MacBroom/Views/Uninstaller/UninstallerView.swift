import SwiftUI
import AppKit

struct UninstallerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = AppScanner()
    @State private var query: String = ""
    @State private var appToConfirm: InstalledApp?
    @State private var runningAppPrompt: InstalledApp?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .uninstaller,
                subtitle: "Remove apps and their leftover files in one shot"
            )

            toolbar
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            Divider()

            if scanner.apps.isEmpty && !scanner.isScanning {
                emptyState
            } else if filteredApps.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxHeight: .infinity)
            } else {
                appList
            }

            Divider()
            footer
        }
        .task {
            if scanner.lastScanDate == nil {
                await scanner.scan()
            }
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(
                get: { appToConfirm != nil },
                set: { if !$0 { appToConfirm = nil } }
            ),
            presenting: appToConfirm
        ) { app in
            Button("Move to Trash", role: .destructive) {
                Task { await performUninstall(app, forceQuit: false) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { app in
            Text(confirmMessage(for: app))
        }
        .confirmationDialog(
            runningAppPromptTitle,
            isPresented: Binding(
                get: { runningAppPrompt != nil },
                set: { if !$0 { runningAppPrompt = nil } }
            ),
            presenting: runningAppPrompt
        ) { app in
            Button("Quit and uninstall", role: .destructive) {
                Task { await performUninstall(app, forceQuit: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { app in
            Text("\(app.displayName) is currently running. Quit it first, then uninstall? This may also kill background helpers.")
        }
        .alert(
            "Uninstall failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func performUninstall(_ app: InstalledApp, forceQuit: Bool) async {
        let result = await scanner.uninstall(app, forceQuitIfRunning: forceQuit)
        if result.wasRunning && !forceQuit {
            runningAppPrompt = app
            return
        }
        if result.appTrashed {
            appState.signalCleanup(reclaimed: result.reclaimed)
        } else if let message = result.errorMessage {
            errorMessage = "\(app.displayName): \(message)"
        } else if result.failedCount > 0 {
            errorMessage = "\(app.displayName) could not be moved to Trash. It may be protected by macOS or still locked by a helper process."
        }
    }

    private var runningAppPromptTitle: String {
        runningAppPrompt.map { "\($0.displayName) is running" } ?? "App is running"
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await scanner.scan() }
            } label: {
                Label(scanner.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(scanner.isScanning)

            if scanner.isScanning {
                SweepingBroomLoader(size: 24)
            }

            Spacer()

            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
        }
    }

    // MARK: - List

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    AppRow(app: app) {
                        appToConfirm = app
                    }
                    Divider().opacity(0.3).padding(.leading, 76)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private var filteredApps: [InstalledApp] {
        guard !query.isEmpty else { return scanner.apps }
        let q = query.lowercased()
        return scanner.apps.filter {
            $0.displayName.lowercased().contains(q) ||
            ($0.bundleId?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView(
            "No apps found",
            systemImage: "app.dashed",
            description: Text("Run a scan to list apps from /Applications.")
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        let totalBytes = scanner.apps.reduce(0) { $0 + $1.totalSize }
        let leftoversBytes = scanner.apps.reduce(0) { $0 + $1.leftoversSize }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scanner.apps.count) apps · \(FileSystemUtils.formatBytes(totalBytes)) total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(FileSystemUtils.formatBytes(leftoversBytes)) in leftover files")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = scanner.lastScanDate {
                Text("Last scan: \(date, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
    }

    // MARK: - Confirm copy

    private var confirmTitle: String {
        if let app = appToConfirm { return "Uninstall \(app.displayName)?" }
        return "Uninstall app?"
    }

    private func confirmMessage(for app: InstalledApp) -> String {
        var lines: [String] = []
        lines.append("App bundle: \(FileSystemUtils.formatBytes(app.appSize))")
        if !app.leftovers.isEmpty {
            lines.append("\(app.leftovers.count) leftover item\(app.leftovers.count == 1 ? "" : "s"): \(FileSystemUtils.formatBytes(app.leftoversSize))")
        }
        lines.append("Total: \(FileSystemUtils.formatBytes(app.totalSize))")
        if app.isApple {
            lines.append("⚠️ This is an Apple-signed app. Removing it may affect macOS features.")
        }
        lines.append("All items will be moved to the Trash.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Row

private struct AppRow: View {
    let app: InstalledApp
    let onUninstall: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .interpolation(.medium)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if app.isApple {
                        Image(systemName: "applelogo")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .help("Apple-signed app")
                    }
                }
                Text(app.bundleId ?? app.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !app.leftovers.isEmpty {
                    Text("+ \(app.leftovers.count) leftover item\(app.leftovers.count == 1 ? "" : "s") · \(FileSystemUtils.formatBytes(app.leftoversSize))")
                        .font(.system(size: 11))
                        .foregroundStyle(SidebarItem.uninstaller.tint)
                }
            }

            Spacer(minLength: 12)

            Text(FileSystemUtils.formatBytes(app.totalSize))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Button(action: onUninstall) {
                Label("Uninstall", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(SidebarItem.uninstaller.tint)
            .help("Uninstall and remove leftovers")
        }
        .padding(.vertical, 10)
    }
}
