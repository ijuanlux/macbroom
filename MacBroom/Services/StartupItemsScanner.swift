import Foundation

struct StartupItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let plistURL: URL
    let scope: Scope
    let program: String?
    let isDisabledInPlist: Bool

    enum Scope: String, Hashable {
        case userAgent   = "~/Library/LaunchAgents"
        case systemAgent = "/Library/LaunchAgents"
        case daemon      = "/Library/LaunchDaemons"
    }

    var requiresAdmin: Bool { scope != .userAgent }
}

@MainActor
final class StartupItemsScanner: ObservableObject {
    @Published private(set) var items: [StartupItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        items = []
        defer { isScanning = false }

        let found = await Task.detached(priority: .userInitiated) {
            StartupItemsScanner.scanAll()
        }.value
        items = found.sorted {
            if $0.scope != $1.scope { return $0.scope.rawValue < $1.scope.rawValue }
            return $0.label.lowercased() < $1.label.lowercased()
        }
        lastScanDate = Date()
    }

    /// Toggles the `Disabled` field in the plist (user-level only, no admin).
    func toggleDisabled(_ item: StartupItem) async -> Bool {
        guard !item.requiresAdmin else { return false }
        let url = item.plistURL
        guard var dict = readPlist(at: url) else { return false }
        let newDisabled = !(dict["Disabled"] as? Bool ?? false)
        dict["Disabled"] = newDisabled
        guard writePlist(dict, to: url) else { return false }
        await scan()
        return true
    }

    func grouped() -> [(scope: StartupItem.Scope, items: [StartupItem])] {
        var buckets: [StartupItem.Scope: [StartupItem]] = [:]
        for item in items { buckets[item.scope, default: []].append(item) }
        return StartupItem.Scope.allCases.compactMap { scope in
            guard let items = buckets[scope], !items.isEmpty else { return nil }
            return (scope, items)
        }
    }

    // MARK: - File reading

    private func readPlist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization
            .propertyList(from: data, format: nil) as? [String: Any]
    }

    private func writePlist(_ dict: [String: Any], to url: URL) -> Bool {
        guard let data = try? PropertyListSerialization
            .data(fromPropertyList: dict, format: .xml, options: 0) else { return false }
        do { try data.write(to: url); return true } catch { return false }
    }

    // MARK: - Scan

    nonisolated private static func scanAll() -> [StartupItem] {
        let home = NSHomeDirectory()
        let sources: [(String, StartupItem.Scope)] = [
            ("\(home)/Library/LaunchAgents", .userAgent),
            ("/Library/LaunchAgents",        .systemAgent),
            ("/Library/LaunchDaemons",       .daemon),
        ]
        var results: [StartupItem] = []
        let fm = FileManager.default
        for (path, scope) in sources {
            guard let names = try? fm.contentsOfDirectory(atPath: path) else { continue }
            for name in names where name.hasSuffix(".plist") {
                let url = URL(fileURLWithPath: "\(path)/\(name)")
                guard let data = try? Data(contentsOf: url),
                      let dict = try? PropertyListSerialization
                        .propertyList(from: data, format: nil) as? [String: Any] else { continue }
                let label = (dict["Label"] as? String) ?? name.replacingOccurrences(of: ".plist", with: "")
                let disabled = (dict["Disabled"] as? Bool) ?? false
                var program = dict["Program"] as? String
                if program == nil, let args = dict["ProgramArguments"] as? [String], let first = args.first {
                    program = first
                }
                results.append(StartupItem(
                    label: label, plistURL: url, scope: scope,
                    program: program, isDisabledInPlist: disabled
                ))
            }
        }
        return results
    }
}

extension StartupItem.Scope: CaseIterable {
    static var allCases: [StartupItem.Scope] {
        [.userAgent, .systemAgent, .daemon]
    }

    var displayName: String {
        switch self {
        case .userAgent:   return "User LaunchAgents (you)"
        case .systemAgent: return "System LaunchAgents (all users)"
        case .daemon:      return "System Daemons (root)"
        }
    }
}
