import Foundation
import SwiftUI

/// Persistent badge catalog + unlock state. Triggers from anywhere in the app
/// via `AchievementsStore.shared.unlock(_:)`. Recent unlock fires a toast via
/// the published `recentlyUnlocked` property.
struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let systemImage: String
    let tint: Color

    static let catalog: [Achievement] = [
        .init(id: "first_sweep",   title: "First Sweep",        blurb: "First successful cleanup",
              systemImage: "wind",                 tint: Color(red: 0.40, green: 0.74, blue: 0.36)),
        .init(id: "reclaim_1gb",   title: "Featherweight",      blurb: "1 GB reclaimed",
              systemImage: "feather",              tint: Color(red: 0.18, green: 0.56, blue: 0.86)),
        .init(id: "reclaim_10gb",  title: "Bulk Sweeper",       blurb: "10 GB reclaimed",
              systemImage: "trash.fill",           tint: Color(red: 0.96, green: 0.55, blue: 0.18)),
        .init(id: "reclaim_100gb", title: "Demolition Crew",    blurb: "100 GB reclaimed",
              systemImage: "hammer.fill",          tint: Color(red: 0.91, green: 0.30, blue: 0.27)),
        .init(id: "reclaim_1tb",   title: "Terabyte Hunter",    blurb: "1 TB reclaimed",
              systemImage: "trophy.fill",          tint: Color(red: 0.61, green: 0.34, blue: 0.71)),
        .init(id: "streak_3",      title: "On a Roll",          blurb: "3-day cleanup streak",
              systemImage: "flame.fill",           tint: Color(red: 0.96, green: 0.55, blue: 0.18)),
        .init(id: "streak_7",      title: "Sweep Week",         blurb: "7-day cleanup streak",
              systemImage: "flame.fill",           tint: Color(red: 0.91, green: 0.30, blue: 0.27)),
        .init(id: "hadouken_master", title: "Hadouken Master",  blurb: "Fired Hadoukens 5 times",
              systemImage: "bolt.fill",            tint: Color(red: 0.85, green: 0.14, blue: 0.18)),
        .init(id: "web_swinger",   title: "Web Swinger",        blurb: "Went Spider-Man",
              systemImage: "figure.climbing",      tint: Color(red: 0.18, green: 0.56, blue: 0.86)),
        .init(id: "b_boy",         title: "B-Boy",              blurb: "Did a breakdance",
              systemImage: "music.note",           tint: Color(red: 0.40, green: 0.74, blue: 0.36)),
        .init(id: "dj_apple",      title: "DJ Apple",           blurb: "Played music 3 times",
              systemImage: "headphones",           tint: Color(red: 0.61, green: 0.34, blue: 0.71)),
        .init(id: "early_bird",    title: "Early Bird",         blurb: "Cleaned before 8am",
              systemImage: "sun.max.fill",         tint: Color(red: 0.98, green: 0.78, blue: 0.20)),
        .init(id: "night_owl",     title: "Night Owl",          blurb: "Cleaned past midnight",
              systemImage: "moon.fill",            tint: Color(red: 0.34, green: 0.30, blue: 0.62)),
    ]
}

@MainActor
final class AchievementsStore: ObservableObject {
    static let shared = AchievementsStore()

    @Published private(set) var unlocked: Set<String> = []
    @Published private(set) var unlockDates: [String: Date] = [:]
    @Published var recentlyUnlocked: Achievement?
    @Published private(set) var hadoukenCount: Int = 0
    @Published private(set) var danceCount: Int = 0

    private let defaults = UserDefaults.standard
    private enum Key {
        static let unlocked = "macbroom.achievements.unlocked"
        static let dates    = "macbroom.achievements.dates"
        static let had      = "macbroom.achievements.hadoukenCount"
        static let dance    = "macbroom.achievements.danceCount"
    }

    init() { load() }

    func unlock(_ id: String) {
        guard !unlocked.contains(id),
              let badge = Achievement.catalog.first(where: { $0.id == id }) else { return }
        unlocked.insert(id)
        unlockDates[id] = Date()
        recentlyUnlocked = badge
        save()
        // Auto-dismiss the toast after a while
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_500_000_000)
            if recentlyUnlocked?.id == id { recentlyUnlocked = nil }
        }
    }

    func acknowledgeReclaim(total: Int64) {
        if total >= 1 << 30                  { unlock("reclaim_1gb") }
        if total >= 10 * (1 << 30)           { unlock("reclaim_10gb") }
        if total >= 100 * (1 << 30)          { unlock("reclaim_100gb") }
        if total >= 1024 * Int64(1 << 30)    { unlock("reclaim_1tb") }
    }

    func acknowledgeCleanup(now: Date = Date()) {
        unlock("first_sweep")
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 8 { unlock("early_bird") }
        if hour == 0 || hour == 1 || hour >= 23 { unlock("night_owl") }
    }

    func acknowledgeStreak(days: Int) {
        if days >= 3 { unlock("streak_3") }
        if days >= 7 { unlock("streak_7") }
    }

    func acknowledgeHadouken() {
        hadoukenCount += 1
        if hadoukenCount >= 5 { unlock("hadouken_master") }
        save()
    }
    func acknowledgeSpiderman() { unlock("web_swinger") }
    func acknowledgeBreakdance() { unlock("b_boy") }
    func acknowledgeDance() {
        danceCount += 1
        if danceCount >= 3 { unlock("dj_apple") }
        save()
    }

    private func load() {
        unlocked = Set(defaults.stringArray(forKey: Key.unlocked) ?? [])
        if let dict = defaults.dictionary(forKey: Key.dates) as? [String: TimeInterval] {
            unlockDates = dict.mapValues { Date(timeIntervalSinceReferenceDate: $0) }
        }
        hadoukenCount = defaults.integer(forKey: Key.had)
        danceCount = defaults.integer(forKey: Key.dance)
    }
    private func save() {
        defaults.set(Array(unlocked), forKey: Key.unlocked)
        let raw = unlockDates.mapValues { $0.timeIntervalSinceReferenceDate }
        defaults.set(raw, forKey: Key.dates)
        defaults.set(hadoukenCount, forKey: Key.had)
        defaults.set(danceCount, forKey: Key.dance)
    }
}
