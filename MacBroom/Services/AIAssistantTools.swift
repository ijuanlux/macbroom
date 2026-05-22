import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Notification names used by AI tools to drive Home-scene animations.
/// HomeView subscribes and runs the matching local animation.
extension Notification.Name {
    static let macbroomRunFullCleanup    = Notification.Name("macbroom.ai.runFullCleanup")
    static let macbroomMakeAppleDance    = Notification.Name("macbroom.ai.makeAppleDance")
    static let macbroomMakeAppleBreakdance = Notification.Name("macbroom.ai.makeAppleBreakdance")
    static let macbroomMakeAppleSpiderman  = Notification.Name("macbroom.ai.makeAppleSpiderman")
    static let macbroomMakeAppleRyu        = Notification.Name("macbroom.ai.makeAppleRyu")
    static let macbroomRoastMe             = Notification.Name("macbroom.ai.roastMe")
    static let macbroomMakeAppleGoku       = Notification.Name("macbroom.ai.makeAppleGoku")
    static let macbroomMakeAppleHulk       = Notification.Name("macbroom.ai.makeAppleHulk")
    static let macbroomMakeApplePikachu    = Notification.Name("macbroom.ai.makeApplePikachu")
    static let macbroomMakeAppleMario      = Notification.Name("macbroom.ai.makeAppleMario")
}

/// Read-only tools exposed to the Foundation Models session.
/// Each tool wraps an existing scanner, returns a plain-text summary the model
/// can quote, and optionally pushes a `AIChatAction` so the UI can offer a
/// "Clean now" button — destructive work always requires a user click.
enum AIAssistantTools {

    /// Drained by `AIAssistant.ask` at the end of a turn.
    @MainActor private static var collectedActions: [AIChatAction] = []

    @MainActor static func drainActions() -> [AIChatAction] {
        let a = collectedActions
        collectedActions = []
        return a
    }

    @MainActor static func push(_ action: AIChatAction) {
        collectedActions.append(action)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    static func all() -> [any Tool] {
        return [
            SearchLargeFilesTool(),
            FindDevJunkTool(),
            AnalyzeCachesTool(),
            FindDuplicatesTool(),
            GetDiskInfoTool(),
            CleanMyMacTool(),
            MakeAppleDanceTool(),
            MakeAppleBreakdanceTool(),
            MakeAppleSpidermanTool(),
            MakeAppleRyuTool(),
            MakeAppleGokuTool(),
            MakeAppleHulkTool(),
            MakeApplePikachuTool(),
            MakeAppleMarioTool(),
            ListLargestAppsTool(),
        ]
    }
    #endif
}

#if canImport(FoundationModels)

// MARK: - Search large files

@available(macOS 26.0, *)
struct SearchLargeFilesTool: Tool {
    let name = "search_large_files"
    let description = """
    Search the user's home directory for files larger than a given size in \
    megabytes. Use this when the user asks about big files, space hogs, large \
    videos, downloads, archives, etc.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Minimum file size in megabytes (e.g. 100, 500, 1000).")
        var minSizeMB: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let threshold = max(1, arguments.minSizeMB)
        let bytes = Int64(threshold) * 1024 * 1024
        let scanner = await LargeFilesScanner()
        await scanner.scan(threshold: bytes)
        let items = await scanner.items
        let total = await scanner.totalSize
        if items.isEmpty {
            return "No files larger than \(threshold) MB found in the user's home directory."
        }
        let top = items.prefix(5).map { item in
            "\(item.url.lastPathComponent) — \(FileSystemUtils.formatBytes(item.sizeBytes)) (in \(item.parentLabel))"
        }.joined(separator: "; ")
        return """
        Found \(items.count) files larger than \(threshold) MB, totaling \
        \(FileSystemUtils.formatBytes(total)). Top items: \(top).
        """
    }
}

// MARK: - Dev junk

@available(macOS 26.0, *)
struct FindDevJunkTool: Tool {
    let name = "find_dev_junk"
    let description = """
    Scan for developer junk: node_modules, Xcode DerivedData, .gradle, Pods, \
    .next, target/ folders, Carthage builds, Swift Package caches. Use this \
    when the user asks about node_modules, Xcode caches, dev folders, build \
    artifacts, "dev junk", etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let scanner = await DevJunkScanner()
        await scanner.scan()
        let items = await scanner.items
        let total = await scanner.totalSize
        if items.isEmpty {
            return "No developer junk found."
        }
        let topNames = items.prefix(4).map { "\($0.displayName) (\(FileSystemUtils.formatBytes($0.sizeBytes)))" }
            .joined(separator: ", ")
        await MainActor.run {
            AIAssistantTools.push(AIChatAction(
                label: "Clean now · \(FileSystemUtils.formatBytes(total))",
                systemImage: "hammer.fill"
            ) {
                NotificationCenter.default.post(name: .macbroomRunFullCleanup, object: nil)
                return "On it — watch me sweep!"
            })
        }
        return """
        Found \(items.count) dev-junk locations totaling \
        \(FileSystemUtils.formatBytes(total)). Largest: \(topNames).
        """
    }
}

// MARK: - Caches

@available(macOS 26.0, *)
struct AnalyzeCachesTool: Tool {
    let name = "analyze_caches"
    let description = """
    Scan user and system caches across ~/Library/Caches and similar. Use when \
    the user asks about caches, temp files, app caches, "freshen up", etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let scanner = await CacheScanner()
        await scanner.scan()
        let items = await scanner.items
        let total = await scanner.totalSize
        if items.isEmpty {
            return "No reclaimable caches found."
        }
        let topNames = items.prefix(4).map { "\($0.displayName) (\(FileSystemUtils.formatBytes($0.sizeBytes)))" }
            .joined(separator: ", ")
        await MainActor.run {
            AIAssistantTools.push(AIChatAction(
                label: "Clean now · \(FileSystemUtils.formatBytes(total))",
                systemImage: "externaldrive.badge.minus"
            ) {
                NotificationCenter.default.post(name: .macbroomRunFullCleanup, object: nil)
                return "On it — watch me sweep!"
            })
        }
        return """
        Found \(items.count) cache items totaling \
        \(FileSystemUtils.formatBytes(total)). Largest: \(topNames).
        """
    }
}

// MARK: - Duplicates

@available(macOS 26.0, *)
struct FindDuplicatesTool: Tool {
    let name = "find_duplicates"
    let description = """
    Find bit-identical duplicate files (SHA-256) in the user's home directory. \
    Use this when the user asks about duplicates, "same file twice", "wasted \
    copies", etc. This can take a while — warn the user it's slow.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let finder = await DuplicateFinder()
        await finder.scan()
        let groups = await finder.groups
        let waste = await finder.totalWaste
        if groups.isEmpty {
            return "No duplicate files found."
        }
        return """
        Found \(groups.count) duplicate groups, reclaimable: \
        \(FileSystemUtils.formatBytes(waste)). Open the Duplicates section to pick which copies to remove.
        """
    }
}

// MARK: - Trigger the apple character

/// Triggers the full SmartScan + cleanup with the apple character animation.
@available(macOS 26.0, *)
struct CleanMyMacTool: Tool {
    let name = "clean_my_mac"
    let description = """
    Run a full cleanup of the user's Mac: scan caches + dev junk and remove \
    everything. The apple character on the Home scene will visibly do the work — \
    walking around, sweeping with the broom, dunking trash in the bin, then \
    sitting on the chair with a coke. Use this when the user says "clean my \
    Mac", "clean up", "limpia mi mac", "do it now", etc. Always prefer this \
    over individual cache/devjunk cleans when the user just wants things gone.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            NotificationCenter.default.post(name: .macbroomRunFullCleanup, object: nil)
        }
        return "On it — watch me sweep your Mac 🧹"
    }
}

/// Make the apple put on DJ headphones, pull out an iPod, and dance.
@available(macOS 26.0, *)
struct MakeAppleDanceTool: Tool {
    let name = "make_apple_dance"
    let description = """
    Make the apple character pull out an iPod, put on DJ headphones, and dance \
    in place for a few seconds. Use when the user asks the apple to dance, \
    listen to music, vibe, put music on, etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            NotificationCenter.default.post(name: .macbroomMakeAppleDance, object: nil)
        }
        return "🎵 Putting on the headphones — let's vibe."
    }
}

/// Make the apple do a 360° spin breakdance animation.
@available(macOS 26.0, *)
struct MakeAppleBreakdanceTool: Tool {
    let name = "make_apple_breakdance"
    let description = """
    Make the apple character do a full breakdance — windmill spin on the floor, \
    multiple rotations. Use when the user explicitly asks for breakdance, \
    spin, b-boy moves, etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            NotificationCenter.default.post(name: .macbroomMakeAppleBreakdance, object: nil)
        }
        return "BREAKDANCE TIME 🕺 watch this"
    }
}

/// Turn the apple into Spider-Man — suit on, web shot, climb to ceiling, drop down.
@available(macOS 26.0, *)
struct MakeAppleSpidermanTool: Tool {
    let name = "make_apple_spiderman"
    let description = """
    Transform the apple character into Spider-Man: he puts on a red and blue \
    suit, shoots a web up to the ceiling with a 'thwip!', climbs up the web, \
    hangs there, then drops back down. Use when the user asks for spiderman, \
    spider, web, climb the ceiling, swing, superhero, "be spidey", etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            NotificationCenter.default.post(name: .macbroomMakeAppleSpiderman, object: nil)
        }
        return "🕷️ Thwip! With great power…"
    }
}

/// Turn the apple into Ryu and fire Hadoukens at every piece of trash.
@available(macOS 26.0, *)
struct MakeAppleRyuTool: Tool {
    let name = "make_apple_ryu"
    let description = """
    Turn the apple into Ryu from Street Fighter: white karate gi + red headband, \
    then he walks around the room firing Hadouken energy balls that obliterate \
    each piece of trash on the floor. Use when the user asks for Ryu, Street \
    Fighter, Hadouken, karate, "destroy the trash", "fight mode", "shoryuken", etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            NotificationCenter.default.post(name: .macbroomMakeAppleRyu, object: nil)
        }
        return "🥋 HADOUKEN incoming!"
    }
}

/// Goku Super Saiyan mode — gold palette + Kamehameha beam.
@available(macOS 26.0, *)
struct MakeAppleGokuTool: Tool {
    let name = "make_apple_goku"
    let description = "Turn the apple into Super Saiyan Goku and fire a Kamehameha beam that obliterates trash. Use for: goku, kamehameha, dragon ball, super saiyan."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { NotificationCenter.default.post(name: .macbroomMakeAppleGoku, object: nil) }
        return "KAAAA... MEEEE... HAAAA... 💥"
    }
}

/// Hulk smash — green palette + ground pound.
@available(macOS 26.0, *)
struct MakeAppleHulkTool: Tool {
    let name = "make_apple_hulk"
    let description = "Turn the apple into Hulk: huge green form, smashes the floor and obliterates trash with debris columns. Use for: hulk, smash, angry, green giant."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { NotificationCenter.default.post(name: .macbroomMakeAppleHulk, object: nil) }
        return "HULK SMASH! 💚"
    }
}

/// Pikachu — yellow palette + chain lightning between trash.
@available(macOS 26.0, *)
struct MakeApplePikachuTool: Tool {
    let name = "make_apple_pikachu"
    let description = "Turn the apple into Pikachu: yellow palette, chain lightning across all trash, everything explodes at once. Use for: pikachu, pokemon, electric, thunderbolt."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { NotificationCenter.default.post(name: .macbroomMakeApplePikachu, object: nil) }
        return "PIKAA... CHUUU!!! ⚡"
    }
}

/// Mario — red+blue palette + bouncing jumps on each trash with coins.
@available(macOS 26.0, *)
struct MakeAppleMarioTool: Tool {
    let name = "make_apple_mario"
    let description = "Turn the apple into Mario: red/blue palette, bounces on each trash piece with coin pops. Use for: mario, nintendo, jumpman, super mario."
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { NotificationCenter.default.post(name: .macbroomMakeAppleMario, object: nil) }
        return "It's a-me, Mario! 🍄"
    }
}

/// Lists installed apps in /Applications by total size.
@available(macOS 26.0, *)
struct ListLargestAppsTool: Tool {
    let name = "list_largest_apps"
    let description = """
    List installed applications from /Applications sorted by their on-disk \
    size, largest first. Use when the user asks about biggest apps, what \
    apps take the most space, "apps más grandes", "biggest installs", etc. \
    Does NOT use search_large_files for this — apps live in /Applications, \
    not Downloads/Documents.
    """

    @Generable struct Arguments {
        @Guide(description: "Max apps to return (default 8, capped at 20).")
        var limit: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let limit = max(1, min(arguments.limit ?? 8, 20))
        let scanner = await AppScanner()
        await scanner.scan()
        let apps = await scanner.apps
        let top = apps.sorted { $0.appSize > $1.appSize }.prefix(limit)
        if top.isEmpty { return "No installed apps found in /Applications." }
        let combined = top.reduce(Int64(0)) { $0 + $1.appSize }
        let listing = top.enumerated().map { idx, app in
            "\(idx + 1). \(app.displayName) — \(FileSystemUtils.formatBytes(app.appSize))"
        }.joined(separator: "\n")
        return """
        Top \(top.count) installed apps (\(FileSystemUtils.formatBytes(combined)) combined):
        \(listing)
        """
    }
}

// MARK: - Disk info

@available(macOS 26.0, *)
struct GetDiskInfoTool: Tool {
    let name = "get_disk_info"
    let description = """
    Return current disk usage: total capacity, used space, available space, and \
    the largest categories. Use when the user asks "what's eating my disk?", \
    "how full am I?", "disk usage", etc.
    """

    @Generable struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let scanner = await StorageScanner()
        await scanner.scan()
        let total = await scanner.totalBytes
        let avail = await scanner.availableBytes
        let used = await scanner.usedBytes
        let usages = await scanner.usages
        let topCats = usages.prefix(4).map {
            "\($0.category.rawValue): \(FileSystemUtils.formatBytes($0.sizeBytes))"
        }.joined(separator: ", ")
        return """
        Disk: \(FileSystemUtils.formatBytes(used)) used / \
        \(FileSystemUtils.formatBytes(total)) total (\
        \(FileSystemUtils.formatBytes(avail)) free). Largest categories: \(topCats).
        """
    }
}

#endif
