import Foundation
import AppKit

@MainActor
final class CacheScanner: ObservableObject {
    @Published private(set) var items: [ScanItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanError: String?

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanError = nil
        items = []
        defer { isScanning = false }

        let roots = Self.cacheRoots()
        let collected = await Task.detached(priority: .userInitiated) {
            CacheScanner.scanRoots(roots)
        }.value

        items = collected.sorted { $0.sizeBytes > $1.sizeBytes }
        lastScanDate = Date()
    }

    func clean(_ targets: [ScanItem]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
        let result = await FileSystemUtils.recycle(targets.map(\.url))
        let trashed = result.trashed

        var removed = 0
        var reclaimed: Int64 = 0
        var failed = 0
        for item in targets {
            if trashed.contains(item.url) {
                removed += 1
                reclaimed += item.sizeBytes
            } else {
                failed += 1
            }
        }
        items.removeAll { item in trashed.contains(item.url) }
        return (removed, reclaimed, failed)
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Scan internals

    private static func cacheRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
        ]
    }

    nonisolated private static func scanRoots(_ roots: [URL]) -> [ScanItem] {
        var results: [ScanItem] = []
        let fm = FileManager.default

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                if SafetyPreferences.shared.isExcluded(entry) { continue }
                let size = FileSystemUtils.size(of: entry)
                if size <= 0 { continue }
                let bundleId = inferBundleId(from: entry.lastPathComponent)
                let displayName = humanName(for: entry.lastPathComponent, bundleId: bundleId)
                results.append(ScanItem(
                    url: entry,
                    displayName: displayName,
                    sizeBytes: size,
                    kind: .appCache(bundleId: bundleId)
                ))
            }
        }

        return results
    }

    /// If the folder name looks like a bundle ID (com.foo.bar), return it.
    nonisolated private static func inferBundleId(from name: String) -> String? {
        // Bundle IDs look like reverse-DNS: at least two dots and lowercase letters.
        guard name.contains("."), !name.hasPrefix(".") else { return nil }
        let parts = name.split(separator: ".")
        return parts.count >= 2 ? name : nil
    }

    nonisolated private static func humanName(for folderName: String, bundleId: String?) -> String {
        if let bundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let stem = appURL.deletingPathExtension().lastPathComponent
            return stem
        }
        return folderName
    }
}
