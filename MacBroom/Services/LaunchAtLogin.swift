import Foundation
import ServiceManagement
import AppKit

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true on success.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("[MacBroom] LaunchAtLogin toggle failed: %@", error.localizedDescription)
            return false
        }
    }
}

@MainActor
enum DockVisibility {
    /// Show or hide the Dock icon. When hidden, the app behaves as a menu-bar accessory.
    static func setShown(_ shown: Bool) {
        let policy: NSApplication.ActivationPolicy = shown ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        if shown {
            // Pull main window to front again when switching back to regular policy.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
