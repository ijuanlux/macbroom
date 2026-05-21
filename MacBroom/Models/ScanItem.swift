import Foundation

struct ScanItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let displayName: String
    var sizeBytes: Int64
    let kind: Kind

    enum Kind: Hashable {
        case appCache(bundleId: String?)
        case userLog
        case devArtifact(category: DevCategory)
        case appBundle
        case leftover(forApp: String)
    }

    enum DevCategory: String, Hashable, CaseIterable {
        case xcodeDerived       = "Xcode DerivedData"
        case xcodeArchives      = "Xcode Archives"
        case xcodeDeviceSupport = "Xcode DeviceSupport"
        case xcodeSimulators    = "iOS Simulators"
        case docker             = "Docker"
        case npm                = "npm cache"
        case yarn               = "Yarn cache"
        case pnpm               = "pnpm cache"
        case pip                = "pip cache"
        case cargo              = "Cargo cache"
        case gradle             = "Gradle cache"
        case maven              = "Maven cache"
        case gem                = "RubyGems"
        case brewDownloads      = "Homebrew downloads"
        case carthage           = "Carthage"
        case cocoapods          = "CocoaPods"

        var systemImage: String {
            switch self {
            case .xcodeDerived, .xcodeArchives, .xcodeDeviceSupport, .xcodeSimulators:
                return "hammer.fill"
            case .docker:                  return "shippingbox.fill"
            case .npm, .yarn, .pnpm:       return "shippingbox"
            case .pip:                     return "ladybug.fill"
            case .cargo:                   return "shippingbox.and.arrow.backward"
            case .gradle, .maven:          return "g.circle.fill"
            case .gem:                     return "diamond.fill"
            case .brewDownloads:           return "cup.and.saucer.fill"
            case .carthage, .cocoapods:    return "swift"
            }
        }
    }
}
