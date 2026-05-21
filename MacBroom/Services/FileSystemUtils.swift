import Foundation
import AppKit

enum FileSystemUtils {
    /// Recursive size of a file or directory, in bytes.
    /// Uses allocated size (on-disk) to match Finder's "Get Info".
    static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }

        if values.isDirectory == true {
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { return 0 }

            var total: Int64 = 0
            for case let child as URL in enumerator {
                let v = try? child.resourceValues(forKeys: Set(keys))
                let allocated = v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0
                total += Int64(allocated)
            }
            return total
        } else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
    }

    /// Move to Trash (reversible). Returns true on success.
    /// Uses `FileManager.trashItem` which works for user-owned files but fails silently
    /// for system-protected paths (e.g. /Applications). Prefer `recycle(_:)` for those.
    @discardableResult
    static func moveToTrash(_ url: URL) -> Bool {
        var resulting: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
            return true
        } catch {
            return false
        }
    }

    /// Move multiple items to Trash. First tries `NSWorkspace.recycle` (fast path for
    /// user-owned files). For items that fail with permission errors (admin-owned files
    /// in /Applications), falls back to AppleScript-via-Finder which shows the standard
    /// macOS admin password prompt.
    static func recycle(_ urls: [URL]) async -> (trashed: Set<URL>, error: Error?) {
        guard !urls.isEmpty else { return ([], nil) }

        // Step 1: NSWorkspace fast path.
        let first = await recycleViaWorkspace(urls)
        let remaining = urls.filter { !first.trashed.contains($0) }
        guard !remaining.isEmpty else { return (first.trashed, nil) }

        // Step 2: anything left needs Finder + admin auth.
        let viaFinder = await recycleViaFinder(remaining)
        var combined = first.trashed
        for url in viaFinder.trashed { combined.insert(url) }

        let finalError = viaFinder.error ?? first.error
        return (combined, combined.count < urls.count ? finalError : nil)
    }

    // MARK: - Implementations

    private static func recycleViaWorkspace(_ urls: [URL]) async -> (trashed: Set<URL>, error: Error?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(trashed: Set<URL>, error: Error?), Never>) in
            NSWorkspace.shared.recycle(urls) { trashed, error in
                if let error {
                    NSLog("[MacBroom] NSWorkspace.recycle failed: %@", error.localizedDescription)
                }
                continuation.resume(returning: (Set(trashed.keys), error))
            }
        }
    }

    /// Asks Finder via AppleScript to move items to Trash. Finder is a privileged
    /// process and shows the standard macOS auth prompt when items are root-owned.
    private static func recycleViaFinder(_ urls: [URL]) async -> (trashed: Set<URL>, error: Error?) {
        let script = makeFinderTrashScript(for: urls)
        return await withCheckedContinuation { (continuation: CheckedContinuation<(trashed: Set<URL>, error: Error?), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var errorInfo: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                _ = appleScript?.executeAndReturnError(&errorInfo)

                let fm = FileManager.default
                let stillExists = urls.filter { fm.fileExists(atPath: $0.path) }
                let trashed = Set(urls).subtracting(stillExists)

                var error: Error?
                if let info = errorInfo {
                    let message = info[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
                    NSLog("[MacBroom] Finder script error: %@", message)
                    if trashed.count < urls.count {
                        error = NSError(
                            domain: "MacBroom",
                            code: (info[NSAppleScript.errorNumber] as? Int) ?? -1,
                            userInfo: [NSLocalizedDescriptionKey: message]
                        )
                    }
                }
                continuation.resume(returning: (trashed, error))
            }
        }
    }

    private static func makeFinderTrashScript(for urls: [URL]) -> String {
        let items = urls.map { url -> String in
            let escapedPath = url.path
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "POSIX file \"\(escapedPath)\""
        }.joined(separator: ", ")
        return """
        tell application "Finder"
            delete {\(items)}
        end tell
        """
    }

    /// Pretty bytes (uses macOS-style binary base = 1024 for parity with Finder/About this Mac).
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
}
