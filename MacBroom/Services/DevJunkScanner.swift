import Foundation

@MainActor
final class DevJunkScanner: ObservableObject {
    @Published private(set) var items: [ScanItem] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        items = []
        defer { isScanning = false }

        let targets = Self.knownTargets()
        let collected = await Task.detached(priority: .userInitiated) {
            DevJunkScanner.measure(targets)
        }.value

        items = collected.sorted { $0.sizeBytes > $1.sizeBytes }
        lastScanDate = Date()
    }

    func clean(_ targets: [ScanItem]) async -> (removed: Int, reclaimed: Int64, failed: Int) {
        let result = await FileSystemUtils.recycle(targets.map(\.url))
        let trashed = result.trashed

        var removed = 0
        var reclaimed: Int64 = 0
        var failed = 0
        for item in targets {
            if trashed.contains(item.url) {
                removed += 1
                reclaimed += item.sizeBytes
            } else {
                failed += 1
            }
        }
        items.removeAll { item in trashed.contains(item.url) }
        return (removed, reclaimed, failed)
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    func grouped() -> [(category: ScanItem.DevCategory, items: [ScanItem], total: Int64)] {
        var buckets: [ScanItem.DevCategory: [ScanItem]] = [:]
        for item in items {
            guard case let .devArtifact(category) = item.kind else { continue }
            buckets[category, default: []].append(item)
        }
        return buckets
            .map { (category: $0.key, items: $0.value, total: $0.value.reduce(0) { $0 + $1.sizeBytes }) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Targets

    private struct DevTarget {
        let path: String
        let displayName: String
        let category: ScanItem.DevCategory
        /// If true, scan immediate children and emit one item per child (e.g. each DerivedData/<Project> separately).
        let expandChildren: Bool
    }

    private static func knownTargets() -> [DevTarget] {
        let home = NSHomeDirectory()
        return [
            DevTarget(path: "\(home)/Library/Developer/Xcode/DerivedData",
                      displayName: "DerivedData",
                      category: .xcodeDerived,
                      expandChildren: true),
            DevTarget(path: "\(home)/Library/Developer/Xcode/Archives",
                      displayName: "Archives",
                      category: .xcodeArchives,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
                      displayName: "iOS DeviceSupport",
                      category: .xcodeDeviceSupport,
                      expandChildren: true),
            DevTarget(path: "\(home)/Library/Developer/CoreSimulator/Caches",
                      displayName: "Simulator caches",
                      category: .xcodeSimulators,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Containers/com.docker.docker/Data/vms",
                      displayName: "Docker VM data",
                      category: .docker,
                      expandChildren: false),
            DevTarget(path: "\(home)/.docker/desktop",
                      displayName: "Docker Desktop",
                      category: .docker,
                      expandChildren: false),
            DevTarget(path: "\(home)/.npm/_cacache",
                      displayName: "npm cache",
                      category: .npm,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/Yarn",
                      displayName: "Yarn cache",
                      category: .yarn,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/pnpm/store",
                      displayName: "pnpm store",
                      category: .pnpm,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/pip",
                      displayName: "pip cache",
                      category: .pip,
                      expandChildren: false),
            DevTarget(path: "\(home)/.cache/pip",
                      displayName: "pip cache (.cache)",
                      category: .pip,
                      expandChildren: false),
            DevTarget(path: "\(home)/.cargo/registry/cache",
                      displayName: "Cargo registry",
                      category: .cargo,
                      expandChildren: false),
            DevTarget(path: "\(home)/.cargo/git/db",
                      displayName: "Cargo git",
                      category: .cargo,
                      expandChildren: false),
            DevTarget(path: "\(home)/.gradle/caches",
                      displayName: "Gradle caches",
                      category: .gradle,
                      expandChildren: false),
            DevTarget(path: "\(home)/.m2/repository",
                      displayName: "Maven repository",
                      category: .maven,
                      expandChildren: false),
            DevTarget(path: "\(home)/.gem",
                      displayName: "RubyGems",
                      category: .gem,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/Homebrew/downloads",
                      displayName: "Homebrew downloads",
                      category: .brewDownloads,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/Homebrew/Cask",
                      displayName: "Homebrew Cask",
                      category: .brewDownloads,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/org.carthage.CarthageKit",
                      displayName: "Carthage cache",
                      category: .carthage,
                      expandChildren: false),
            DevTarget(path: "\(home)/Library/Caches/CocoaPods",
                      displayName: "CocoaPods cache",
                      category: .cocoapods,
                      expandChildren: false),
        ]
    }

    nonisolated private static func measure(_ targets: [DevTarget]) -> [ScanItem] {
        let fm = FileManager.default
        var results: [ScanItem] = []

        for target in targets {
            let url = URL(fileURLWithPath: target.path)
            guard fm.fileExists(atPath: target.path) else { continue }

            if target.expandChildren,
               let children = try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]) {
                for child in children {
                    let size = FileSystemUtils.size(of: child)
                    guard size > 0 else { continue }
                    results.append(ScanItem(
                        url: child,
                        displayName: child.lastPathComponent,
                        sizeBytes: size,
                        kind: .devArtifact(category: target.category)
                    ))
                }
            } else {
                let size = FileSystemUtils.size(of: url)
                guard size > 0 else { continue }
                results.append(ScanItem(
                    url: url,
                    displayName: target.displayName,
                    sizeBytes: size,
                    kind: .devArtifact(category: target.category)
                ))
            }
        }

        return results
    }
}
