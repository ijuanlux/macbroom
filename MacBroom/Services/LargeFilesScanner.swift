import Foundation

struct LargeFileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    let modifiedAt: Date?
    let parentLabel: String   // e.g. "Downloads" / "Documents"
}

@MainActor
final class LargeFilesScanner: ObservableObject {
    @Published private(set) var items: [LargeFileItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?
    /// True when at least one root folder couldn't be read (TCC denied).
    /// LargeFilesView shows a "grant access" hint in that case.
    @Published private(set) var permissionDenied: Bool = false
    /// Names of the folders that were blocked by macOS this scan.
    @Published private(set) var deniedRoots: [String] = []

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    /// Threshold in bytes (default 100 MB). Files smaller than this are ignored.
    func scan(threshold: Int64 = 100 * 1024 * 1024) async {
        guard !isScanning else { return }
        isScanning = true
        items = []
        permissionDenied = false
        deniedRoots = []
        defer { isScanning = false }

        let snapshot = await Task.detached(priority: .userInitiated) {
            LargeFilesScanner.scanRoots(threshold: threshold)
        }.value

        items = snapshot.items.sorted { $0.sizeBytes > $1.sizeBytes }
        deniedRoots = snapshot.deniedRoots
        permissionDenied = !snapshot.deniedRoots.isEmpty
        lastScanDate = Date()
    }

    func clean(_ targets: [LargeFileItem]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
        let result = await FileSystemUtils.recycle(targets.map(\.url))
        let trashed = result.trashed
        var reclaimed: Int64 = 0
        var removed = 0
        var failed = 0
        for target in targets {
            if trashed.contains(target.url) {
                reclaimed += target.sizeBytes
                removed += 1
            } else {
                failed += 1
            }
        }
        items.removeAll { trashed.contains($0.url) }
        return (removed, reclaimed, failed)
    }

    struct ScanSnapshot {
        let items: [LargeFileItem]
        let deniedRoots: [String]
    }

    nonisolated private static func scanRoots(threshold: Int64) -> ScanSnapshot {
        let home = NSHomeDirectory()
        let roots: [(URL, String)] = [
            (URL(fileURLWithPath: "\(home)/Downloads"), "Downloads"),
            (URL(fileURLWithPath: "\(home)/Documents"), "Documents"),
            (URL(fileURLWithPath: "\(home)/Desktop"),   "Desktop"),
            (URL(fileURLWithPath: "\(home)/Movies"),    "Movies"),
        ]
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .contentModificationDateKey, .isPackageKey
        ]

        var results: [LargeFileItem] = []
        var denied: [String] = []

        for (root, label) in roots {
            guard fm.fileExists(atPath: root.path) else { continue }

            // Probe permission with contentsOfDirectory — if the folder has
            // anything on disk but we read 0 entries, TCC denied us.
            do {
                let probe = try fm.contentsOfDirectory(at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles])
                if probe.isEmpty {
                    // Folder is truly empty — not denial. Skip silently.
                    continue
                }
            } catch {
                denied.append(label)
                continue
            }

            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                denied.append(label)
                continue
            }

            for case let url as URL in enumerator {
                if SafetyPreferences.shared.isExcluded(url) { continue }
                let v = try? url.resourceValues(forKeys: keys)
                if v?.isDirectory == true { continue }
                let size = Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
                guard size >= threshold else { continue }
                results.append(LargeFileItem(
                    url: url,
                    sizeBytes: size,
                    modifiedAt: v?.contentModificationDate,
                    parentLabel: label
                ))
            }
        }
        return ScanSnapshot(items: results, deniedRoots: denied)
    }
}
