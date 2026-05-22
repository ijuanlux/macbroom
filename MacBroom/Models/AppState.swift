import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selection: SidebarItem? = .home
    @Published var splashDismissed: Bool = false
    @Published var paletteVisible: Bool = false
    /// Set when the user drops a folder onto the Dock icon — DiskExplorerView reads + clears this.
    @Published var requestedExplorerURL: URL?

    /// Increments every time a cleanup completes — drives confetti + toast.
    @Published private(set) var cleanupTrigger: Int = 0
    @Published private(set) var lastReclaimed: Int64 = 0

    let stats = StatsStore()

    func signalCleanup(reclaimed: Int64) {
        lastReclaimed = reclaimed
        cleanupTrigger += 1
        stats.record(reclaimed: reclaimed)
        if reclaimed > 0 {
            SoundEffects.playCleanup()
        }
    }
}
