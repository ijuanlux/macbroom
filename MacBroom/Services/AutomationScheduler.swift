import Foundation

enum SmartScanFrequency: String, CaseIterable, Identifiable {
    case off, daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:     return "Off"
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    var seconds: TimeInterval? {
        switch self {
        case .off:     return nil
        case .daily:   return 24 * 60 * 60
        case .weekly:  return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        }
    }
}

@MainActor
final class AutomationScheduler {
    static let shared = AutomationScheduler()

    private var diskActivity: NSBackgroundActivityScheduler?
    private var scanActivity: NSBackgroundActivityScheduler?

    var onScheduledSmartScan: (() async -> Int64)?

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

    // MARK: - Smart Scan schedule

    func startSmartScanSchedule(_ frequency: SmartScanFrequency) {
        scanActivity?.invalidate()
        scanActivity = nil
        guard let interval = frequency.seconds else { return }

        let activity = NSBackgroundActivityScheduler(
            identifier: "com.juandediego.macbroom.smartscan"
        )
        activity.interval = interval
        activity.tolerance = min(interval * 0.2, 60 * 60)   // up to 1 h tolerance
        activity.repeats = true
        activity.qualityOfService = .background

        activity.schedule { [weak self] completion in
            Task { @MainActor in
                let reclaimed = await self?.onScheduledSmartScan?() ?? 0
                if reclaimed > 0 {
                    NotificationManager.shared.post(
                        title: "Smart Scan reclaimed \(FileSystemUtils.formatBytes(reclaimed))",
                        body: "Scheduled cleanup completed. Open MacBroom for details.",
                        identifier: "macbroom.scheduledscan"
                    )
                }
                completion(.finished)
            }
        }
        scanActivity = activity
    }

    func stopSmartScanSchedule() {
        scanActivity?.invalidate()
        scanActivity = nil
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
