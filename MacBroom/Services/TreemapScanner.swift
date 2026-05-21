import Foundation

struct TreemapNode: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let displayName: String
    let sizeBytes: Int64
    let isDirectory: Bool
}

@MainActor
final class TreemapScanner: ObservableObject {
    @Published private(set) var path: URL
    @Published private(set) var children: [TreemapNode] = []
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var isScanning: Bool = false

    private(set) var history: [URL] = []

    init(path: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.path = path
    }

    func navigate(to url: URL) async {
        history.append(self.path)
        self.path = url
        await scan()
    }

    func goUp() async {
        guard let previous = history.popLast() else {
            // Fallback: parent directory
            let parent = path.deletingLastPathComponent()
            if parent.path != path.path {
                path = parent
                await scan()
            }
            return
        }
        path = previous
        await scan()
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let target = path
        let result = await Task.detached(priority: .userInitiated) {
            TreemapScanner.measureChildren(of: target)
        }.value

        children = result.children.sorted { $0.sizeBytes > $1.sizeBytes }
        totalSize = result.total
    }

    nonisolated private static func measureChildren(of url: URL) -> (children: [TreemapNode], total: Int64) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], 0)
        }
        var nodes: [TreemapNode] = []
        var total: Int64 = 0
        for entry in entries {
            let v = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = v?.isDirectory == true
            let size = FileSystemUtils.size(of: entry)
            guard size > 0 else { continue }
            total += size
            nodes.append(TreemapNode(
                url: entry,
                displayName: entry.lastPathComponent,
                sizeBytes: size,
                isDirectory: isDir
            ))
        }
        return (nodes, total)
    }
}
