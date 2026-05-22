import Foundation

struct DiskSnapshot: Hashable {
    let timestamp: Date
    let freeBytes: Int64
    let totalBytes: Int64
}

struct DiskForecast {
    /// Bytes consumed per day (positive = filling up, negative = freeing).
    let bytesPerDay: Int64
    /// Days remaining before disk is full, nil if data insufficient or trend is freeing.
    let daysUntilFull: Int?
    let lookbackDays: Int
}

@MainActor
final class DiskTrendStore: ObservableObject {
    static let shared = DiskTrendStore()

    @Published private(set) var history: [DiskSnapshot] = []

    private let defaults: UserDefaults
    private let key = "macbroom.diskTrend.history"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Snapshot the disk state. Skips if the most recent snapshot is from today.
    func snapshotIfNeeded() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = history.last, cal.startOfDay(for: last.timestamp) == today {
            return
        }

        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let v = try? url.resourceValues(forKeys: keys) else { return }
        let total = Int64(v.volumeTotalCapacity ?? 0)
        let free = v.volumeAvailableCapacityForImportantUsage
            ?? Int64(v.volumeAvailableCapacity ?? 0)
        guard total > 0 else { return }

        history.append(DiskSnapshot(timestamp: Date(), freeBytes: free, totalBytes: total))
        // Keep ~90 days of history
        let cutoff = cal.date(byAdding: .day, value: -90, to: today) ?? today
        history.removeAll { $0.timestamp < cutoff }
        save()
    }

    /// Returns nil if there's not enough data (need ≥ 2 snapshots spanning ≥ 3 days).
    func forecast() -> DiskForecast? {
        guard history.count >= 2 else { return nil }
        guard let oldest = history.first, let newest = history.last else { return nil }
        let days = max(1, Calendar.current.dateComponents([.day], from: oldest.timestamp, to: newest.timestamp).day ?? 0)
        guard days >= 3 else { return nil }

        let consumed = oldest.freeBytes - newest.freeBytes   // positive = filled up
        let perDay = consumed / Int64(days)
        let daysLeft: Int?
        if perDay > 0 {
            daysLeft = Int(newest.freeBytes / perDay)
        } else {
            daysLeft = nil
        }
        return DiskForecast(bytesPerDay: perDay, daysUntilFull: daysLeft, lookbackDays: days)
    }

    private func load() {
        guard let raw = defaults.array(forKey: key) as? [[String: Any]] else { return }
        history = raw.compactMap { dict in
            guard let ts = dict["t"] as? TimeInterval,
                  let free = dict["f"] as? NSNumber,
                  let total = dict["x"] as? NSNumber else { return nil }
            return DiskSnapshot(
                timestamp: Date(timeIntervalSinceReferenceDate: ts),
                freeBytes: free.int64Value,
                totalBytes: total.int64Value
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }

    private func save() {
        let raw: [[String: Any]] = history.map {
            ["t": $0.timestamp.timeIntervalSinceReferenceDate,
             "f": NSNumber(value: $0.freeBytes),
             "x": NSNumber(value: $0.totalBytes)]
        }
        defaults.set(raw, forKey: key)
    }
}
