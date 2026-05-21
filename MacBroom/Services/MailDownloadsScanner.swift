import Foundation

struct MailDownloadItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    let modifiedAt: Date?
    let source: Source

    enum Source: Hashable {
        case mailAttachment
        case oldDownload
    }
}

@MainActor
final class MailDownloadsScanner: ObservableObject {
    @Published private(set) var items: [MailDownloadItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    /// Files in Downloads older than this many days are considered "old".
    nonisolated private static let staleAfterDays: Int = 30

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        items = []
        defer { isScanning = false }

        let collected = await Task.detached(priority: .userInitiated) {
            MailDownloadsScanner.scanAll()
        }.value

        items = collected.sorted { $0.sizeBytes > $1.sizeBytes }
        lastScanDate = Date()
    }

    func clean(_ targets: [MailDownloadItem]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
        let result = await FileSystemUtils.recycle(targets.map(\.url))
        let trashed = result.trashed
        var removed = 0
        var reclaimed: Int64 = 0
        var failed = 0
        for target in targets {
            if trashed.contains(target.url) { removed += 1; reclaimed += target.sizeBytes }
            else { failed += 1 }
        }
        items.removeAll { trashed.contains($0.url) }
        return (removed, reclaimed, failed)
    }

    nonisolated private static func scanAll() -> [MailDownloadItem] {
        let home = NSHomeDirectory()
        var results: [MailDownloadItem] = []
        let fm = FileManager.default

        // Mail attachments
        let mailRoots = [
            "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
            "\(home)/Library/Mail Downloads"
        ]
        for root in mailRoots {
            guard fm.fileExists(atPath: root) else { continue }
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let url as URL in enumerator {
                    let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .contentModificationDateKey])
                    if v?.isDirectory == true { continue }
                    let size = Int64(v?.totalFileAllocatedSize ?? 0)
                    guard size > 0 else { continue }
                    results.append(MailDownloadItem(
                        url: url, sizeBytes: size, modifiedAt: v?.contentModificationDate,
                        source: .mailAttachment))
                }
            }
        }

        // Old downloads (>staleAfterDays old)
        let downloadsURL = URL(fileURLWithPath: "\(home)/Downloads")
        let cutoff = Date().addingTimeInterval(-Double(staleAfterDays) * 86400)
        if let contents = try? fm.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents {
                let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .contentModificationDateKey])
                guard let modified = v?.contentModificationDate, modified < cutoff else { continue }
                let size = FileSystemUtils.size(of: url)
                guard size > 0 else { continue }
                results.append(MailDownloadItem(
                    url: url, sizeBytes: size, modifiedAt: modified,
                    source: .oldDownload))
            }
        }

        return results
    }
}
