import Foundation

@MainActor
final class AutomationScheduler {
    static let shared = AutomationScheduler()

    private var diskActivity: NSBackgroundActivityScheduler?

    private init() {}

    /// Starts watching disk space. Fires every ~15 min while the app is running and posts
    /// a notification when free space drops below `thresholdPercent` of total.
    func startDiskWatcher(thresholdPercent: Double = 10) {
        diskActivity?.invalidate()
        let activity = NSBackgroundActivityScheduler(
            identifier: "com.juandediego.macbroom.diskwatcher"
        )
        activity.interval = 60 * 15  // 15 min
        activity.tolerance = 60 * 5
        activity.repeats = true
        activity.qualityOfService = .background

        activity.schedule { [weak self] completion in
            self?.checkDiskSpace(thresholdPercent: thresholdPercent)
            completion(.finished)
        }
        diskActivity = activity
    }

    func stop() {
        diskActivity?.invalidate()
        diskActivity = nil
    }

    nonisolated private func checkDiskSpace(thresholdPercent: Double) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey,
                                         .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? url.resourceValues(forKeys: keys),
              let total = v.volumeTotalCapacity,
              let avail = v.volumeAvailableCapacityForImportantUsage,
              total > 0 else { return }

        let pct = Double(avail) / Double(total) * 100
        if pct < thresholdPercent {
            Task { @MainActor in
                NotificationManager.shared.post(
                    title: "Mac is running low on space",
                    body: "Only \(String(format: "%.1f", pct))% free. Run Smart Scan to reclaim space.",
                    identifier: "macbroom.lowdisk"
                )
            }
        }
    }
}
