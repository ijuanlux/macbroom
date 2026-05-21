import SwiftUI

enum StorageCategory: String, CaseIterable, Identifiable, Hashable {
    case apps        = "Applications"
    case documents   = "Documents"
    case desktop     = "Desktop"
    case downloads   = "Downloads"
    case photos      = "Photos"
    case music       = "Music"
    case movies      = "Movies"
    case userLibrary = "User Library"
    case developer   = "Developer"
    case other       = "Other"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .apps:        return Theme.stripeBlue
        case .documents:   return Theme.stripeGreen
        case .desktop:     return Theme.stripeYellow
        case .downloads:   return Theme.stripeOrange
        case .photos:      return Color(red: 0.95, green: 0.45, blue: 0.55)
        case .music:       return Color(red: 0.85, green: 0.35, blue: 0.65)
        case .movies:      return Theme.stripeRed
        case .userLibrary: return Color(red: 0.50, green: 0.55, blue: 0.65)
        case .developer:   return Theme.stripePurple
        case .other:       return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }

    var systemImage: String {
        switch self {
        case .apps:        return "app.fill"
        case .documents:   return "doc.fill"
        case .desktop:     return "macwindow"
        case .downloads:   return "arrow.down.circle.fill"
        case .photos:      return "photo.fill"
        case .music:       return "music.note"
        case .movies:      return "film.fill"
        case .userLibrary: return "books.vertical.fill"
        case .developer:   return "hammer.fill"
        case .other:       return "circle.fill"
        }
    }
}

struct CategoryUsage: Identifiable, Hashable {
    let category: StorageCategory
    var sizeBytes: Int64
    var id: StorageCategory { category }
}
