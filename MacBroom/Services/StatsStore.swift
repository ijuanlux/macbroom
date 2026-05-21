import Foundation

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var totalReclaimed: Int64 = 0
    @Published private(set) var cleanupCount: Int = 0
    @Published private(set) var firstUseDate: Date = Date()
    @Published private(set) var lastCleanupDate: Date?

    private enum Key {
        static let total = "macbroom.stats.totalReclaimed"
        static let count = "macbroom.stats.cleanupCount"
        static let firstUse = "macbroom.stats.firstUseDate"
        static let lastCleanup = "macbroom.stats.lastCleanupDate"
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
        save()
    }

    var daysSinceFirstUse: Int {
        Calendar.current.dateComponents([.day], from: firstUseDate, to: Date()).day ?? 0
    }

    private func load() {
        totalReclaimed = defaults.object(forKey: Key.total) as? Int64 ?? 0
        cleanupCount = defaults.integer(forKey: Key.count)
        firstUseDate = defaults.object(forKey: Key.firstUse) as? Date ?? Date()
        lastCleanupDate = defaults.object(forKey: Key.lastCleanup) as? Date
        // Persist first-use date on first launch.
        if defaults.object(forKey: Key.firstUse) == nil {
            defaults.set(firstUseDate, forKey: Key.firstUse)
        }
    }

    private func save() {
        defaults.set(totalReclaimed, forKey: Key.total)
        defaults.set(cleanupCount, forKey: Key.count)
        defaults.set(lastCleanupDate, forKey: Key.lastCleanup)
    }
}
