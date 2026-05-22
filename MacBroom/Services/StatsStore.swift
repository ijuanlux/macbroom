import Foundation

struct DailyCleanup: Identifiable, Hashable {
    var id: Date { day }
    let day: Date            // normalized to startOfDay
    let bytes: Int64
}

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var totalReclaimed: Int64 = 0
    @Published private(set) var cleanupCount: Int = 0
    @Published private(set) var firstUseDate: Date = Date()
    @Published private(set) var lastCleanupDate: Date?
    /// One bar per calendar day, oldest first, last 30 days.
    @Published private(set) var dailyHistory: [DailyCleanup] = []

    private enum Key {
        static let total = "macbroom.stats.totalReclaimed"
        static let count = "macbroom.stats.cleanupCount"
        static let firstUse = "macbroom.stats.firstUseDate"
        static let lastCleanup = "macbroom.stats.lastCleanupDate"
        static let daily = "macbroom.stats.dailyHistory"   // [TimeInterval: Int64]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(reclaimed: Int64) {
        guard reclaimed > 0 else { return }
        totalReclaimed += reclaimed
        cleanupCount += 1
        lastCleanupDate = Date()
        appendDaily(bytes: reclaimed)
        save()
    }

    var daysSinceFirstUse: Int {
        Calendar.current.dateComponents([.day], from: firstUseDate, to: Date()).day ?? 0
    }

    /// Returns 30 entries (one per day), filling zero-byte days so the chart aligns.
    func last30Days() -> [DailyCleanup] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let byDay = Dictionary(uniqueKeysWithValues: dailyHistory.map { ($0.day, $0.bytes) })
        var out: [DailyCleanup] = []
        for offset in (0..<30).reversed() {
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let bytes = byDay[day] ?? 0
            out.append(DailyCleanup(day: day, bytes: bytes))
        }
        return out
    }

    private func appendDaily(bytes: Int64) {
        let today = Calendar.current.startOfDay(for: Date())
        var dict = Dictionary(uniqueKeysWithValues: dailyHistory.map { ($0.day, $0.bytes) })
        dict[today, default: 0] += bytes
        // Drop entries older than 90 days to keep storage tiny
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
        dict = dict.filter { $0.key >= cutoff }
        dailyHistory = dict.map { DailyCleanup(day: $0.key, bytes: $0.value) }.sorted { $0.day < $1.day }
    }

    private func load() {
        totalReclaimed = defaults.object(forKey: Key.total) as? Int64 ?? 0
        cleanupCount = defaults.integer(forKey: Key.count)
        firstUseDate = defaults.object(forKey: Key.firstUse) as? Date ?? Date()
        lastCleanupDate = defaults.object(forKey: Key.lastCleanup) as? Date
        if defaults.object(forKey: Key.firstUse) == nil {
            defaults.set(firstUseDate, forKey: Key.firstUse)
        }
        // Daily history stored as [TimeInterval: Int64]
        if let raw = defaults.object(forKey: Key.daily) as? [String: NSNumber] {
            let cal = Calendar.current
            dailyHistory = raw.compactMap { key, value in
                guard let ts = TimeInterval(key) else { return nil }
                let day = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: ts))
                return DailyCleanup(day: day, bytes: value.int64Value)
            }.sorted { $0.day < $1.day }
        }
    }

    private func save() {
        defaults.set(totalReclaimed, forKey: Key.total)
        defaults.set(cleanupCount, forKey: Key.count)
        defaults.set(lastCleanupDate, forKey: Key.lastCleanup)
        // Persist daily as [String(timeInterval): NSNumber(bytes)]
        var raw: [String: NSNumber] = [:]
        for entry in dailyHistory {
            raw[String(entry.day.timeIntervalSinceReferenceDate)] = NSNumber(value: entry.bytes)
        }
        defaults.set(raw, forKey: Key.daily)
    }
}
