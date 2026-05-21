import Foundation

@MainActor
final class StorageScanner: ObservableObject {
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var availableBytes: Int64 = 0
    @Published private(set) var usages: [CategoryUsage] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    var usedBytes: Int64 { max(0, totalBytes - availableBytes) }

    var measuredBytes: Int64 {
        usages.reduce(0) { $0 + $1.sizeBytes }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        loadVolumeInfo()

        let snapshot = await Task.detached(priority: .userInitiated) {
            StorageScanner.measureAll()
        }.value

        // Compute "Other" so the bar fills up to usedBytes.
        var measured = snapshot
        let knownTotal = measured.reduce(0) { $0 + $1.sizeBytes }
        let other = max(0, usedBytes - knownTotal)
        measured.append(CategoryUsage(category: .other, sizeBytes: other))

        usages = measured.sorted { $0.sizeBytes > $1.sizeBytes }
        lastScanDate = Date()
    }

    // MARK: - Volume

    private func loadVolumeInfo() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return }
        totalBytes = Int64(values.volumeTotalCapacity ?? 0)
        availableBytes = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
    }

    // MARK: - Per-category measurement

    nonisolated private static func measureAll() -> [CategoryUsage] {
        let home = NSHomeDirectory()
        let categories: [(StorageCategory, [String])] = [
            (.apps,        ["/Applications", "\(home)/Applications"]),
            (.documents,   ["\(home)/Documents"]),
            (.desktop,     ["\(home)/Desktop"]),
            (.downloads,   ["\(home)/Downloads"]),
            (.photos,      ["\(home)/Pictures"]),
            (.music,       ["\(home)/Music"]),
            (.movies,      ["\(home)/Movies"]),
            (.developer,   ["\(home)/Library/Developer"]),
            // User Library minus Developer (we count Developer separately).
            (.userLibrary, ["\(home)/Library"]),
        ]

        var byCategory: [StorageCategory: Int64] = [:]
        let fm = FileManager.default

        for (category, paths) in categories {
            var total: Int64 = 0
            for path in paths {
                guard fm.fileExists(atPath: path) else { continue }
                total += FileSystemUtils.size(of: URL(fileURLWithPath: path))
            }
            byCategory[category] = total
        }

        // Subtract Developer from User Library so we don't double-count.
        if let lib = byCategory[.userLibrary], let dev = byCategory[.developer] {
            byCategory[.userLibrary] = max(0, lib - dev)
        }

        return byCategory
            .filter { $0.value > 0 }
            .map { CategoryUsage(category: $0.key, sizeBytes: $0.value) }
    }
}
