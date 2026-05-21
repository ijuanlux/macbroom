import SwiftUI

struct MaintenanceAction: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let systemImage: String
    let command: String
    let requiresAdmin: Bool
}

enum MaintenanceCatalog {
    static let all: [MaintenanceAction] = [
        .init(id: "purge",
              title: "Free inactive memory",
              blurb: "Force the kernel to free inactive RAM pages.",
              systemImage: "memorychip",
              command: "/usr/sbin/purge",
              requiresAdmin: true),
        .init(id: "flushdns",
              title: "Flush DNS cache",
              blurb: "Fixes \"server not found\" issues after switching networks.",
              systemImage: "network",
              command: "dscacheutil -flushcache && killall -HUP mDNSResponder",
              requiresAdmin: true),
        .init(id: "rebuildSpotlight",
              title: "Rebuild Spotlight index",
              blurb: "Re-index the boot volume — fixes blank Spotlight results.",
              systemImage: "magnifyingglass",
              command: "mdutil -E /",
              requiresAdmin: true),
        .init(id: "verifyDisk",
              title: "Verify startup disk",
              blurb: "Runs diskutil verify on the boot volume.",
              systemImage: "internaldrive",
              command: "diskutil verifyVolume /",
              requiresAdmin: true),
        .init(id: "fontCache",
              title: "Clear font caches",
              blurb: "Fixes garbled text and missing fonts.",
              systemImage: "textformat",
              command: "atsutil databases -remove && atsutil server -shutdown && atsutil server -ping",
              requiresAdmin: true),
        .init(id: "resetLaunchpad",
              title: "Reset Launchpad",
              blurb: "Restore the original app order in Launchpad.",
              systemImage: "square.grid.3x3",
              command: "defaults write com.apple.dock ResetLaunchPad -bool true; killall Dock",
              requiresAdmin: false),
        .init(id: "clearReports",
              title: "Clear diagnostic reports",
              blurb: "Delete crash logs from ~/Library/Logs/DiagnosticReports.",
              systemImage: "doc.text.below.ecg",
              command: "rm -rf ~/Library/Logs/DiagnosticReports/*",
              requiresAdmin: false),
        .init(id: "emptyTrash",
              title: "Force empty Trash",
              blurb: "Ignores locked files. Cannot be undone.",
              systemImage: "trash",
              command: "rm -rf ~/.Trash/* ~/.Trash/.[!.]*",
              requiresAdmin: false),
        .init(id: "flushDock",
              title: "Restart Dock",
              blurb: "Force-quits the Dock — picks up changed icons & badges.",
              systemImage: "macwindow.on.rectangle",
              command: "killall Dock",
              requiresAdmin: false),
        .init(id: "flushFinder",
              title: "Restart Finder",
              blurb: "Force-quits Finder — fixes ghost windows and stale views.",
              systemImage: "macwindow",
              command: "killall Finder",
              requiresAdmin: false),
    ]
}
