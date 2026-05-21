import Foundation
import AppKit

@MainActor
final class AppScanner: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        defer { isScanning = false }

        let results = await Task.detached(priority: .userInitiated) {
            AppScanner.scanApps()
        }.value

        apps = results.sorted { $0.totalSize > $1.totalSize }
        lastScanDate = Date()
    }

    struct UninstallResult {
        let appTrashed: Bool
        let reclaimed: Int64
        let failedCount: Int
        let errorMessage: String?
        let wasRunning: Bool
    }

    func uninstall(_ app: InstalledApp, forceQuitIfRunning: Bool = false) async -> UninstallResult {
        // Detect running instance
        let runningInstances = Self.runningInstances(of: app)
        let wasRunning = !runningInstances.isEmpty

        if wasRunning && !forceQuitIfRunning {
            return UninstallResult(
                appTrashed: false, reclaimed: 0, failedCount: 0,
                errorMessage: nil, wasRunning: true
            )
        }

        if wasRunning {
            for running in runningInstances {
                running.terminate()
            }
            // Give the OS a moment to release file locks.
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        var urls = [app.url]
        urls.append(contentsOf: app.leftovers.map(\.url))

        let result = await FileSystemUtils.recycle(urls)
        let trashed = result.trashed

        var reclaimed: Int64 = 0
        var failed = 0
        let appTrashed = trashed.contains(app.url)
        if appTrashed { reclaimed += app.appSize } else { failed += 1 }

        for leftover in app.leftovers {
            if trashed.contains(leftover.url) {
                reclaimed += leftover.sizeBytes
            } else {
                failed += 1
            }
        }

        if appTrashed {
            apps.removeAll { $0.id == app.id }
        }

        return UninstallResult(
            appTrashed: appTrashed,
            reclaimed: reclaimed,
            failedCount: failed,
            errorMessage: result.error?.localizedDescription,
            wasRunning: wasRunning
        )
    }

    private static func runningInstances(of app: InstalledApp) -> [NSRunningApplication] {
        let running = NSWorkspace.shared.runningApplications
        if let bundleId = app.bundleId {
            return running.filter { $0.bundleIdentifier == bundleId }
        }
        return running.filter { $0.bundleURL == app.url }
    }

    // MARK: - Scan internals

    nonisolated private static func scanApps() -> [InstalledApp] {
        let home = NSHomeDirectory()
        let locations = ["/Applications", "\(home)/Applications"]
        let fm = FileManager.default
        var results: [InstalledApp] = []

        for location in locations {
            guard fm.fileExists(atPath: location) else { continue }
            guard let contents = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: location),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                if let app = inspectApp(at: url) {
                    results.append(app)
                }
            }
        }

        return results
    }

    nonisolated private static func inspectApp(at url: URL) -> InstalledApp? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = (try? Data(contentsOf: infoPlistURL))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }

        let bundleId = plist?["CFBundleIdentifier"] as? String
        let displayName = (plist?["CFBundleDisplayName"] as? String)
            ?? (plist?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = plist?["CFBundleShortVersionString"] as? String

        let appSize = FileSystemUtils.size(of: url)
        let leftovers = detectLeftovers(bundleId: bundleId, displayName: displayName)

        return InstalledApp(
            url: url,
            bundleId: bundleId,
            displayName: displayName,
            version: version,
            appSize: appSize,
            leftovers: leftovers
        )
    }

    nonisolated private static func detectLeftovers(bundleId: String?, displayName: String) -> [ScanItem] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        var candidates: [String] = []

        if let bundleId {
            candidates += [
                "\(home)/Library/Application Support/\(bundleId)",
                "\(home)/Library/Caches/\(bundleId)",
                "\(home)/Library/Preferences/\(bundleId).plist",
                "\(home)/Library/Saved Application State/\(bundleId).savedState",
                "\(home)/Library/Containers/\(bundleId)",
                "\(home)/Library/Group Containers/\(bundleId)",
                "\(home)/Library/HTTPStorages/\(bundleId)",
                "\(home)/Library/WebKit/\(bundleId)",
                "\(home)/Library/Cookies/\(bundleId).binarycookies",
                "\(home)/Library/Application Scripts/\(bundleId)",
            ]
        }
        candidates += [
            "\(home)/Library/Application Support/\(displayName)",
            "\(home)/Library/Logs/\(displayName)",
            "\(home)/Library/Caches/\(displayName)",
        ]

        var results: [ScanItem] = []
        var seen = Set<String>()

        for path in candidates {
            guard fm.fileExists(atPath: path), !seen.contains(path) else { continue }
            seen.insert(path)
            let url = URL(fileURLWithPath: path)
            let size = FileSystemUtils.size(of: url)
            guard size > 0 else { continue }
            results.append(ScanItem(
                url: url,
                displayName: url.lastPathComponent,
                sizeBytes: size,
                kind: .leftover(forApp: displayName)
            ))
        }

        return results
    }
}
