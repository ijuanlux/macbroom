import Foundation
import CryptoKit

struct DuplicateFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
}

struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let sizeBytes: Int64
    let hash: String
    var files: [DuplicateFile]

    var wastedBytes: Int64 { sizeBytes * Int64(max(0, files.count - 1)) }
}

@MainActor
final class DuplicateFinder: ObservableObject {
    @Published private(set) var groups: [DuplicateGroup] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var progressNote: String = ""

    /// Total wasted space (files that could be deleted to leave one copy of each).
    var totalWaste: Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }

    /// Minimum file size to consider for dedup (skip tiny files — too many false friends).
    nonisolated private static let minSize: Int64 = 1 * 1024 * 1024 // 1 MB

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        groups = []
        progressNote = "Indexing files…"
        defer { isScanning = false; progressNote = "" }

        let candidates = await Task.detached(priority: .userInitiated) {
            DuplicateFinder.collectCandidates()
        }.value

        // Group by size first
        var bySize: [Int64: [URL]] = [:]
        for entry in candidates { bySize[entry.size, default: []].append(entry.url) }
        let duplicateSizeGroups = bySize.filter { $0.value.count > 1 }
        let totalFilesToHash = duplicateSizeGroups.values.reduce(0) { $0 + $1.count }

        progressNote = "Hashing \(totalFilesToHash) candidates…"

        var byHash: [String: (size: Int64, files: [URL])] = [:]
        var processed = 0
        for (size, urls) in duplicateSizeGroups {
            for url in urls {
                if let h = await Task.detached(priority: .userInitiated, operation: {
                    DuplicateFinder.sha256(of: url)
                }).value {
                    var entry = byHash[h] ?? (size, [])
                    entry.files.append(url)
                    byHash[h] = entry
                }
                processed += 1
                if processed % 25 == 0 {
                    progressNote = "Hashing \(processed)/\(totalFilesToHash)…"
                }
            }
        }

        let collected: [DuplicateGroup] = byHash
            .filter { $0.value.files.count > 1 }
            .map { entry in
                DuplicateGroup(
                    sizeBytes: entry.value.size,
                    hash: entry.key,
                    files: entry.value.files.map { DuplicateFile(url: $0, sizeBytes: entry.value.size) }
                )
            }
            .sorted { $0.wastedBytes > $1.wastedBytes }

        groups = collected
        lastScanDate = Date()
    }

    func clean(_ urls: [URL]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
        let result = await FileSystemUtils.recycle(urls)
        let trashed = result.trashed
        var removed = 0
        var reclaimed: Int64 = 0
        var failed = 0
        for group in groups {
            for file in group.files {
                if urls.contains(file.url) {
                    if trashed.contains(file.url) {
                        removed += 1
                        reclaimed += file.sizeBytes
                    } else {
                        failed += 1
                    }
                }
            }
        }
        // Update groups: strip trashed files; drop groups that now have <2 files.
        groups = groups.compactMap { group in
            var g = group
            g.files.removeAll { trashed.contains($0.url) }
            return g.files.count > 1 ? g : nil
        }
        return (removed, reclaimed, failed)
    }

    nonisolated private static func collectCandidates() -> [(url: URL, size: Int64)] {
        let home = NSHomeDirectory()
        let roots = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
        ]
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
        ]
        var out: [(URL, Int64)] = []
        for root in roots {
            guard fm.fileExists(atPath: root) else { continue }
            guard let e = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in e {
                let v = try? url.resourceValues(forKeys: keys)
                if v?.isDirectory == true { continue }
                let size = Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
                if size >= minSize {
                    out.append((url, size))
                }
            }
        }
        return out
    }

    nonisolated private static func sha256(of url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        let bufferSize = 1 * 1024 * 1024 // 1 MB chunks
        let bufferPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { bufferPtr.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(bufferPtr, maxLength: bufferSize)
            if read <= 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: bufferPtr, count: read))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
