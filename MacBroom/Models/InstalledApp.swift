import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let bundleId: String?
    let displayName: String
    let version: String?
    let appSize: Int64
    var leftovers: [ScanItem] = []

    var leftoversSize: Int64 { leftovers.reduce(0) { $0 + $1.sizeBytes } }
    var totalSize: Int64 { appSize + leftoversSize }

    /// True if the app's bundle id is registered by Apple. We let the user uninstall
    /// these, but mark them so the UI can show a warning.
    var isApple: Bool {
        guard let bundleId else { return false }
        return bundleId.hasPrefix("com.apple.")
    }
}
