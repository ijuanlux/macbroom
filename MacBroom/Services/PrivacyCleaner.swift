import Foundation

struct PrivacyItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let displayName: String
    let browser: Browser
    let sizeBytes: Int64

    enum Browser: String, Hashable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case brave  = "Brave"
        case firefox = "Firefox"
        case edge   = "Microsoft Edge"
        case arc    = "Arc"

        var systemImage: String { "globe" }
    }
}

@MainActor
final class PrivacyCleaner: ObservableObject {
    @Published private(set) var items: [PrivacyItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        items = []
        defer { isScanning = false }

        let found = await Task.detached(priority: .userInitiated) {
            PrivacyCleaner.scanAll()
        }.value

        items = found.sorted { $0.sizeBytes > $1.sizeBytes }
        lastScanDate = Date()
    }

    func clean(_ targets: [PrivacyItem]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
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

    func grouped() -> [(browser: PrivacyItem.Browser, items: [PrivacyItem], total: Int64)] {
        var buckets: [PrivacyItem.Browser: [PrivacyItem]] = [:]
        for item in items { buckets[item.browser, default: []].append(item) }
        return buckets
            .map { (browser: $0.key, items: $0.value, total: $0.value.reduce(0) { $0 + $1.sizeBytes }) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Targets

    nonisolated private static func scanAll() -> [PrivacyItem] {
        let home = NSHomeDirectory()
        let targets: [(path: String, name: String, browser: PrivacyItem.Browser)] = [
            // Safari
            ("\(home)/Library/Safari/History.db",            "History",            .safari),
            ("\(home)/Library/Safari/Downloads.plist",       "Downloads list",     .safari),
            ("\(home)/Library/Cookies/Cookies.binarycookies", "Cookies",           .safari),
            ("\(home)/Library/Safari/LocalStorage",          "LocalStorage",       .safari),
            ("\(home)/Library/Safari/Databases",             "Databases",          .safari),
            // Chrome
            ("\(home)/Library/Application Support/Google/Chrome/Default/Cookies",  "Cookies",  .chrome),
            ("\(home)/Library/Application Support/Google/Chrome/Default/History",  "History",  .chrome),
            ("\(home)/Library/Application Support/Google/Chrome/Default/Cache",    "Cache",    .chrome),
            ("\(home)/Library/Application Support/Google/Chrome/Default/Local Storage", "LocalStorage", .chrome),
            // Brave
            ("\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies", "Cookies", .brave),
            ("\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default/History", "History", .brave),
            ("\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",   "Cache",   .brave),
            // Edge
            ("\(home)/Library/Application Support/Microsoft Edge/Default/Cookies", "Cookies", .edge),
            ("\(home)/Library/Application Support/Microsoft Edge/Default/History", "History", .edge),
            ("\(home)/Library/Application Support/Microsoft Edge/Default/Cache",   "Cache",   .edge),
            // Arc
            ("\(home)/Library/Application Support/Arc/User Data/Default/Cookies",  "Cookies", .arc),
            ("\(home)/Library/Application Support/Arc/User Data/Default/History",  "History", .arc),
            ("\(home)/Library/Application Support/Arc/User Data/Default/Cache",    "Cache",   .arc),
        ]

        let fm = FileManager.default
        var results: [PrivacyItem] = []
        for target in targets {
            guard fm.fileExists(atPath: target.path) else { continue }
            let url = URL(fileURLWithPath: target.path)
            let size = FileSystemUtils.size(of: url)
            guard size > 0 else { continue }
            results.append(PrivacyItem(url: url, displayName: target.name,
                                       browser: target.browser, sizeBytes: size))
        }

        // Firefox profiles — glob all profile dirs and look for typical files.
        let firefoxRoot = "\(home)/Library/Application Support/Firefox/Profiles"
        if let profiles = try? fm.contentsOfDirectory(atPath: firefoxRoot) {
            for profile in profiles {
                let base = "\(firefoxRoot)/\(profile)"
                let candidates: [(String, String)] = [
                    ("cookies.sqlite", "Cookies"),
                    ("places.sqlite",  "History"),
                    ("cache2",         "Cache"),
                    ("storage",        "Local storage"),
                ]
                for (file, label) in candidates {
                    let path = "\(base)/\(file)"
                    guard fm.fileExists(atPath: path) else { continue }
                    let url = URL(fileURLWithPath: path)
                    let size = FileSystemUtils.size(of: url)
                    guard size > 0 else { continue }
                    results.append(PrivacyItem(url: url, displayName: label,
                                               browser: .firefox, sizeBytes: size))
                }
            }
        }

        return results
    }
}
