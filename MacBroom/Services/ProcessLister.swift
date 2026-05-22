import Foundation
import Darwin
import AppKit

struct RunningProcess: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let rssBytes: Int64
    let cpuPercent: Double
    let isApp: Bool
    let bundleURL: URL?

    var displayName: String {
        if let url = bundleURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return name
    }
}

enum ProcessLister {
    /// Returns the top `limit` processes by RSS (resident memory).
    static func topByMemory(limit: Int = 12) -> [RunningProcess] {
        let raw = run("/bin/ps", args: ["-axrm", "-o", "pid=,rss=,%cpu=,comm="])
        let lines = raw.split(separator: "\n").prefix(limit * 2)  // headroom for parse skips
        var apps: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            apps[app.processIdentifier] = app
        }

        var results: [RunningProcess] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4 else { continue }
            guard let pid = Int32(parts[0]),
                  let rss = Int64(parts[1]),
                  let cpu = Double(parts[2]) else { continue }
            // comm is the remainder
            let comm = parts[3...].joined(separator: " ")
            let app = apps[pid]
            let name = app?.localizedName ?? lastPathComponent(of: comm)
            results.append(RunningProcess(
                pid: pid,
                name: name,
                rssBytes: rss * 1024,  // ps reports KB
                cpuPercent: cpu,
                isApp: app != nil,
                bundleURL: app?.bundleURL
            ))
            if results.count >= limit { break }
        }
        return results
    }

    /// Sends SIGTERM. Returns true on success.
    @discardableResult
    static func terminate(_ pid: pid_t) -> Bool {
        kill(pid, SIGTERM) == 0
    }

    /// Sends SIGKILL. Returns true on success.
    @discardableResult
    static func forceKill(_ pid: pid_t) -> Bool {
        kill(pid, SIGKILL) == 0
    }

    private static func run(_ launchPath: String, args: [String]) -> String {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func lastPathComponent(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
}
