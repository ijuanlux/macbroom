import Foundation
import Combine

enum SafetyProfile: String, CaseIterable, Identifiable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }
    var label: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced:     return "Balanced"
        case .aggressive:   return "Aggressive"
        }
    }
    var blurb: String {
        switch self {
        case .conservative: return "Never auto-selects anything. You pick everything by hand."
        case .balanced:     return "Auto-selects safe items only. Skips system caches and Apple-signed apps."
        case .aggressive:   return "Auto-selects everything found, including system caches. Use with care."
        }
    }
}

/// Singleton store for safety settings: profile + excluded paths.
@MainActor
final class SafetyPreferences: ObservableObject {
    static let shared = SafetyPreferences()

    @Published var profile: SafetyProfile {
        didSet {
            UserDefaults.standard.set(profile.rawValue, forKey: profileKey)
        }
    }

    @Published private(set) var excludedPaths: [String] {
        didSet {
            UserDefaults.standard.set(excludedPaths, forKey: excludedKey)
        }
    }

    private let profileKey = "macbroom.safety.profile"
    private let excludedKey = "macbroom.safety.excluded"

    private init() {
        let rawProfile = UserDefaults.standard.string(forKey: profileKey) ?? SafetyProfile.balanced.rawValue
        self.profile = SafetyProfile(rawValue: rawProfile) ?? .balanced
        self.excludedPaths = UserDefaults.standard.stringArray(forKey: excludedKey) ?? []
    }

    func addExcluded(_ path: String) {
        let normalized = (path as NSString).standardizingPath
        guard !excludedPaths.contains(normalized) else { return }
        excludedPaths.append(normalized)
    }

    func removeExcluded(_ path: String) {
        excludedPaths.removeAll { $0 == path }
    }

    /// Returns true if the given URL is inside any excluded path.
    nonisolated func isExcluded(_ url: URL) -> Bool {
        let excluded = UserDefaults.standard.stringArray(forKey: "macbroom.safety.excluded") ?? []
        let path = url.standardizedFileURL.path
        for prefix in excluded {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
}
