import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case caches
    case devJunk
    case uninstaller
    case largeFiles
    case duplicates
    case privacy
    case mail
    case memory
    case maintenance
    case explorer
    case startup
    case hacker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:   return "Dashboard"
        case .caches:      return "Caches"
        case .devJunk:     return "Dev Junk"
        case .uninstaller: return "Uninstaller"
        case .largeFiles:  return "Large Files"
        case .duplicates:  return "Duplicates"
        case .privacy:     return "Privacy"
        case .mail:        return "Mail & Old Downloads"
        case .memory:      return "Memory"
        case .maintenance: return "Maintenance"
        case .explorer:    return "Disk Explorer"
        case .startup:     return "Startup"
        case .hacker:      return "Hacker Mode"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:   return "internaldrive"
        case .caches:      return "tray.full"
        case .devJunk:     return "hammer"
        case .uninstaller: return "trash"
        case .largeFiles:  return "doc.zipper"
        case .duplicates:  return "square.on.square"
        case .privacy:     return "lock.shield"
        case .mail:        return "envelope"
        case .memory:      return "memorychip"
        case .maintenance: return "wrench.and.screwdriver"
        case .explorer:    return "square.grid.2x2"
        case .startup:     return "power"
        case .hacker:      return "terminal"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard:   return Theme.stripeBlue
        case .caches:      return Theme.stripeGreen
        case .devJunk:     return Theme.stripePurple
        case .uninstaller: return Theme.stripeRed
        case .largeFiles:  return Theme.stripeOrange
        case .duplicates:  return Theme.stripeYellow
        case .privacy:     return Color(red: 0.18, green: 0.66, blue: 0.66)
        case .mail:        return Color(red: 0.85, green: 0.35, blue: 0.65)
        case .memory:      return Color(red: 0.40, green: 0.65, blue: 0.95)
        case .maintenance: return Color(red: 0.95, green: 0.55, blue: 0.30)
        case .explorer:    return Color(red: 0.45, green: 0.85, blue: 0.75)
        case .startup:     return Color(red: 0.95, green: 0.78, blue: 0.20)
        case .hacker:      return Color(red: 0.20, green: 0.95, blue: 0.35)
        }
    }
}
