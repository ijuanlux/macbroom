import Foundation

@MainActor
final class HackerFeed: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var heaviestPaths: [(label: String, size: Int64)] = []

    private let storage = StorageScanner()

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        lines = []
        await emit("$ macbroom --hacker-mode --interactive")
        await sleep(350)
        await emit("> initializing volume scan...")
        await sleep(200)
        await emit("> auth: ok  ·  sandbox: disabled  ·  privilege: user")
        await sleep(200)

        await storage.scan()

        await emit("")
        await emit("◆ volume: Macintosh HD")
        await emit("  total      \(FileSystemUtils.formatBytes(storage.totalBytes))")
        await emit("  used       \(FileSystemUtils.formatBytes(storage.usedBytes))  (\(percent(storage.usedBytes, of: storage.totalBytes))%)")
        await emit("  available  \(FileSystemUtils.formatBytes(storage.availableBytes))  (\(percent(storage.availableBytes, of: storage.totalBytes))%)")
        await sleep(300)
        await emit("")
        await emit("◆ heaviest categories")
        let allSorted = storage.usages.sorted { $0.sizeBytes > $1.sizeBytes }
        let topEight = Array(allSorted.prefix(8))
        heaviestPaths = topEight.map { ($0.category.rawValue, $0.sizeBytes) }
        let widest: Int64 = topEight.first?.sizeBytes ?? 1
        for idx in 0..<topEight.count {
            let usage = topEight[idx]
            let barLen = max(1, Int(Double(usage.sizeBytes) / Double(widest) * 28))
            let bar = String(repeating: "█", count: barLen) + String(repeating: "░", count: max(0, 28 - barLen))
            let label = usage.category.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)
            let size = FileSystemUtils.formatBytes(usage.sizeBytes)
            let row = String(format: "  %02d %@  %@  %@", idx + 1, label, bar, size)
            await emit(row)
            await sleep(70)
        }
        await emit("")
        await emit("◆ system")
        await emit("  uptime     \(formatUptime())")
        await emit("  hostname   \(ProcessInfo.processInfo.hostName)")
        await emit("  cpu        \(ProcessInfo.processInfo.processorCount) cores")
        await emit("  memory     \(FileSystemUtils.formatBytes(Int64(ProcessInfo.processInfo.physicalMemory)))")
        await sleep(300)
        await emit("")
        await emit("[READY]")
        await emit("$ run smart-scan to reclaim disk")
    }

    private func emit(_ line: String) async {
        lines.append(line)
    }

    private func sleep(_ ms: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }

    private func percent(_ value: Int64, of total: Int64) -> String {
        guard total > 0 else { return "0" }
        return String(format: "%.1f", Double(value) / Double(total) * 100)
    }

    private func formatUptime() -> String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let mins = (seconds % 3600) / 60
        return "\(days)d \(hours)h \(mins)m"
    }
}
