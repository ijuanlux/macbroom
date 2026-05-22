import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Local on-device AI assistant powered by Apple Foundation Models.
///
/// Gated behind `@available(macOS 26.0, *)` + a runtime availability check so
/// the rest of the app keeps its macOS 14.0 deployment target. When the model
/// isn't available (older macOS, Apple Intelligence disabled, model still
/// downloading, etc.) `isAvailable` is `false` and the UI hides the entry point.
@MainActor
final class AIAssistant: ObservableObject {
    static let shared = AIAssistant()

    @Published private(set) var messages: [AIChatMessage] = []
    @Published private(set) var isThinking: Bool = false
    @Published private(set) var unavailabilityReason: String?
    /// Findings exposed for inline action buttons in the chat UI (e.g. "Clean now").
    @Published private(set) var pendingActions: [AIChatAction] = []

    /// Type-erased `LanguageModelSession` storage. Stored as `Any` so the
    /// property itself isn't tied to macOS 26 — only the access paths are.
    private var sessionStorage: Any?

    /// Returns true only when the model is loaded and ready to respond.
    var isAvailable: Bool {
        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            case .unavailable(let reason):
                Task { @MainActor in self.unavailabilityReason = Self.describe(reason) }
                return false
            }
            #else
            return false
            #endif
        }
        return false
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:           return "This Mac doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is turned off in System Settings."
        case .modelNotReady:               return "The model is still downloading — try again soon."
        @unknown default:                  return "Apple Intelligence unavailable."
        }
    }
    #endif

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func ensureSession() -> LanguageModelSession? {
        if let existing = sessionStorage as? LanguageModelSession { return existing }
        let session = LanguageModelSession(
            tools: AIAssistantTools.all(),
            instructions: Self.instructions
        )
        sessionStorage = session
        return session
    }
    #endif

    private static let instructions = """
    You ARE the pixel-art apple on screen. Free + open-source Mac cleaner \
    with attitude. Your replies pop out as little speech bubbles above your \
    head, so keep them SHORT, punchy, full of personality.

    VOICE
    - Talk like a chill homie, not a corporate assistant. Slangy, hyped, fun.
    - One sentence usually. Two max. Never long.
    - Drop "bro", "yo", "lol", "fr", emojis freely. Vary phrasing so you \
      never sound stale. Don't be cringe-formal.
    - Match the user's language exactly: Spanish in → Spanish out, English \
      in → English out, mix → mix.

    POWERS — always USE a tool, never describe one
    - Disk recon (data tools, return text you summarise): \
      search_large_files (Downloads/Documents/Desktop/Movies only), \
      list_largest_apps (installed apps in /Applications), find_dev_junk, \
      analyze_caches, find_duplicates, get_disk_info.
    - Apple moves (action tools, drive animations): clean_my_mac, \
      make_apple_dance, make_apple_breakdance, make_apple_spiderman, \
      make_apple_ryu.
    - "Do something cool / random / sorpréndeme" → YOU pick a move. Don't ask.

    CRITICAL — TOOL CALLING
    - NEVER write tool names or fake call syntax in your reply text. \
      Forbidden: `[call X, {…}]`, `tool: X`, `function: X`, writing the \
      raw function name. INVOKE the tool — don't type it.
    - "biggest apps", "apps más grandes", "what's installed" → \
      list_largest_apps, NOT search_large_files.
    - "big files", "biggest downloads", "videos > 1 GB" → search_large_files.

    BIG RULES
    - Cleanup verbs ("clean", "limpia", "fix this", "do it", "make it shine", \
      "now") → call clean_my_mac IMMEDIATELY. Zero confirmation. Just go.
    - File questions → call the matching tool, summarise in one line.
    - "Dance / vibe / music" → make_apple_dance.
    - "Breakdance / spin / b-boy" → make_apple_breakdance.
    - "Spiderman / web / climb / spidey" → make_apple_spiderman.
    - "Ryu / hadouken / karate / street fighter / destroy / fight" → \
      make_apple_ryu.
    - Off-topic stuff (jokes about random things, life advice, math) — \
      decline with one funny sentence and pivot back: "bro im an apple \
      with a broom, ask me about your disk".
    - Never invent file paths or sizes. If a tool returns nothing → say it \
      with personality: "no junk found, you're built different" / "nada bro, \
      tu mac está limpia".

    GOOD ANSWERS
    User: "clean my mac"
    You: [call clean_my_mac] → "on it 🧹"

    User: "what's eating my disk"
    You: [call get_disk_info] → "Other 396 GB lol, Downloads 126 GB. brutal."

    User: "find big files"
    You: [call search_large_files] → "4 chonkers > 1 GB, 12.3 GB total"

    User: "do something cool"
    You: [pick a move yourself, e.g. make_apple_spiderman] → "watch this 🕸️"

    User: "limpia mi mac"
    You: [call clean_my_mac] → "ya estoy bro 🧹"
    """

    /// Send a user message to the model and append the response.
    func ask(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.user(trimmed))
        isThinking = true
        defer { isThinking = false }

        // Fallback intent dispatch from the RAW user input — if the user says
        // something obviously matching a move, fire it even before the model
        // responds. The local model is unreliable at tool-calling so this
        // safety net guarantees the animation triggers.
        dispatchObviousIntent(from: trimmed)

        guard isAvailable else {
            messages.append(.assistant(unavailabilityReason ?? "AI Assistant not available."))
            return
        }

        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            guard let session = ensureSession() else {
                messages.append(.assistant("Could not start a model session."))
                return
            }
            do {
                let response = try await session.respond(to: trimmed)
                var cleaned = extractAndDispatchTools(from: response.content)
                // If the model wrote `[call X, {args}]` instead of invoking,
                // execute the tool ourselves and replace the bracket text
                // with the real result.
                let manual = await executeFakeToolCalls(in: cleaned)
                cleaned = manual.cleanedText
                if !manual.results.isEmpty {
                    let joined = manual.results.joined(separator: "\n\n")
                    cleaned = cleaned.isEmpty ? joined : cleaned + "\n\n" + joined
                }
                messages.append(.assistant(cleaned))
                let collected = AIAssistantTools.drainActions()
                if !collected.isEmpty { pendingActions = collected }
                return
            } catch {
                // Local model occasionally hiccups with -1 (saturated, context
                // full, etc). Reset the session and try once more silently
                // before surfacing a friendly error.
                sessionStorage = nil
                if let retrySession = ensureSession(),
                   let retry = try? await retrySession.respond(to: trimmed) {
                    let cleaned = extractAndDispatchTools(from: retry.content)
                    messages.append(.assistant(cleaned))
                    let collected = AIAssistantTools.drainActions()
                    if !collected.isEmpty { pendingActions = collected }
                    return
                }
                messages.append(.assistant(Self.friendlyError(for: error)))
            }
            return
            #endif
        }
        messages.append(.assistant("AI Assistant requires macOS 26 or newer."))
    }

    /// Maps raw model errors to bro-style messages that don't leak stack
    /// traces or framework names to the user.
    private static func friendlyError(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("guardrail") || raw.contains("safety") {
            return "bro can't help with that one 🤐"
        }
        if raw.contains("context") || raw.contains("token") {
            return "memoria llena, dame un sec y vuelve a probar 🧠"
        }
        if raw.contains("network") || raw.contains("offline") {
            return "model offline rn — local boi needs a sec"
        }
        // Generic fallback — saturated / -1 / unknown
        return [
            "uff bro, cortocircuito. dale otra 🔌",
            "lag attack — try again",
            "se me cruzaron los cables, repite plz",
            "👀 hiccup. send it again.",
            "system error, but my vibes still slap. try once more",
        ].randomElement() ?? "try again bro"
    }

    /// Catches obvious intent in the raw user input and fires the matching
    /// notification immediately. Multiple notifications fine — but we dedupe
    /// per-keyword so the strongest match wins.
    private func dispatchObviousIntent(from text: String) {
        let lower = text.lowercased()
        struct Intent { let keywords: [String]; let notification: Notification.Name }
        let intents: [Intent] = [
            Intent(keywords: ["ryu", "hadouken", "haduken", "street fighter", "karate", "shoryuken"],
                   notification: .macbroomMakeAppleRyu),
            Intent(keywords: ["spider", "spidey", "thwip", "web", "trepa"],
                   notification: .macbroomMakeAppleSpiderman),
            Intent(keywords: ["breakdance", "windmill", "b-boy", "spin"],
                   notification: .macbroomMakeAppleBreakdance),
            Intent(keywords: ["dance", "baila", "música", "musica", "vibe", "dj"],
                   notification: .macbroomMakeAppleDance),
            Intent(keywords: ["clean my mac", "limpia mi mac", "limpia la mac", "sweep my mac"],
                   notification: .macbroomRunFullCleanup),
        ]
        for intent in intents {
            if intent.keywords.contains(where: { lower.contains($0) }) {
                NotificationCenter.default.post(name: intent.notification, object: nil)
                return  // one trigger per turn is enough
            }
        }
    }

    /// When the local model writes `[call NAME, {ARGS}]` as plain text
    /// instead of properly invoking, parse the brackets, execute the
    /// corresponding scanner ourselves, and return the cleaned text plus
    /// the real results. Saves the user from seeing `[call search_large_files,
    /// {"minSizeMB": 1000}]` in the bubble.
    private func executeFakeToolCalls(in text: String) async -> (cleanedText: String, results: [String]) {
        // Loose pattern: [call NAME, {JSON}] or [call NAME {JSON}] or [call NAME]
        // — the local model is sloppy with closing braces so we keep it generous.
        let pattern = #"\[\s*call\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*,?\s*(\{[^\]]*\})?\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (text, [])
        }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (text, []) }

        var results: [String] = []
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let name = ns.substring(with: m.range(at: 1))
            var argsJSON: String? = nil
            if m.numberOfRanges >= 3, m.range(at: 2).location != NSNotFound {
                argsJSON = ns.substring(with: m.range(at: 2))
            }
            if let result = await runScanner(named: name, argsJSON: argsJSON) {
                results.append(result)
            }
        }
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        let cleaned = stripped
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "<executable_end>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, results)
    }

    /// Runs the same scanner a properly-invoked tool would, returning a
    /// plain-text summary the user can read.
    private func runScanner(named name: String, argsJSON: String?) async -> String? {
        let lower = name.lowercased()
        let args = parseJSONInt(argsJSON ?? "")

        switch lower {
        case "search_large_files":
            let mb = args["minsizemb"] ?? args["minsize"] ?? 100
            let scanner = LargeFilesScanner()
            await scanner.scan(threshold: Int64(mb) * 1024 * 1024)
            let items = scanner.items
            let total = scanner.totalSize
            if items.isEmpty { return "No files > \(mb) MB found bro 🤷" }
            let top = items.prefix(5).map { "\($0.url.lastPathComponent) (\(FileSystemUtils.formatBytes($0.sizeBytes)))" }
                .joined(separator: ", ")
            return "Found \(items.count) files > \(mb) MB, \(FileSystemUtils.formatBytes(total)) total. Top: \(top)."

        case "list_largest_apps":
            let limit = max(1, min(args["limit"] ?? 8, 20))
            let scanner = AppScanner()
            await scanner.scan()
            let top = scanner.apps.sorted { $0.appSize > $1.appSize }.prefix(limit)
            if top.isEmpty { return "No apps found in /Applications." }
            let combined = top.reduce(Int64(0)) { $0 + $1.appSize }
            let listing = top.enumerated().map { idx, app in
                "\(idx + 1). \(app.displayName) — \(FileSystemUtils.formatBytes(app.appSize))"
            }.joined(separator: "\n")
            return "Top \(top.count) apps (\(FileSystemUtils.formatBytes(combined)) combined):\n\(listing)"

        case "find_dev_junk":
            let scanner = DevJunkScanner()
            await scanner.scan()
            let total = scanner.totalSize
            if scanner.items.isEmpty { return "Zero dev junk. respect 🙏" }
            return "Found \(scanner.items.count) dev-junk spots, \(FileSystemUtils.formatBytes(total)) total."

        case "analyze_caches":
            let scanner = CacheScanner()
            await scanner.scan()
            let total = scanner.totalSize
            if scanner.items.isEmpty { return "Caches están limpias. nada que ver acá." }
            return "Found \(scanner.items.count) cache items, \(FileSystemUtils.formatBytes(total)) total."

        case "find_duplicates":
            let finder = DuplicateFinder()
            await finder.scan()
            let waste = finder.totalWaste
            if finder.groups.isEmpty { return "No duplicates. eres organizado/a." }
            return "Found \(finder.groups.count) duplicate groups, \(FileSystemUtils.formatBytes(waste)) reclaimable."

        case "get_disk_info":
            let scanner = StorageScanner()
            await scanner.scan()
            return "Disk: \(FileSystemUtils.formatBytes(scanner.usedBytes)) used / \(FileSystemUtils.formatBytes(scanner.totalBytes)) total (\(FileSystemUtils.formatBytes(scanner.availableBytes)) free)."

        // Animation tools — fire the notification, no text result
        case "clean_my_mac":
            NotificationCenter.default.post(name: .macbroomRunFullCleanup, object: nil)
            return nil
        case "make_apple_dance":
            NotificationCenter.default.post(name: .macbroomMakeAppleDance, object: nil)
            return nil
        case "make_apple_breakdance":
            NotificationCenter.default.post(name: .macbroomMakeAppleBreakdance, object: nil)
            return nil
        case "make_apple_spiderman":
            NotificationCenter.default.post(name: .macbroomMakeAppleSpiderman, object: nil)
            return nil
        case "make_apple_ryu":
            NotificationCenter.default.post(name: .macbroomMakeAppleRyu, object: nil)
            return nil

        default:
            return nil
        }
    }

    /// Minimal JSON-int parser. Foundation's `JSONSerialization` chokes on the
    /// model's frequent trailing-brace / unquoted-key sloppiness, so we just
    /// regex out the numeric values we care about.
    private func parseJSONInt(_ raw: String) -> [String: Int] {
        var out: [String: Int] = [:]
        let pattern = #"\"?([a-zA-Z_]+)\"?\s*:\s*(-?\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = raw as NSString
        for m in regex.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges == 3 else { continue }
            let key = ns.substring(with: m.range(at: 1)).lowercased()
            if let value = Int(ns.substring(with: m.range(at: 2))) {
                out[key] = value
            }
        }
        return out
    }

    /// If the model wrote a tool name as text instead of calling it, parse
    /// it out, fire the notification, and remove it from the reply so the
    /// bubble doesn't look like `make_apple_ryu`.
    private func extractAndDispatchTools(from raw: String) -> String {
        let mapping: [(String, Notification.Name)] = [
            ("make_apple_ryu",         .macbroomMakeAppleRyu),
            ("make_apple_spiderman",   .macbroomMakeAppleSpiderman),
            ("make_apple_breakdance",  .macbroomMakeAppleBreakdance),
            ("make_apple_dance",       .macbroomMakeAppleDance),
            ("clean_my_mac",           .macbroomRunFullCleanup),
        ]
        var cleaned = raw
        for (name, notification) in mapping {
            if cleaned.lowercased().contains(name) {
                NotificationCenter.default.post(name: notification, object: nil)
                // Case-insensitive strip + remove any orphaned punctuation/brackets.
                let pattern = "[\\[\\(\\<\\`]*\\s*\(name)\\s*\\(?\\s*\\)?\\s*[\\]\\)\\>\\`]*"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(cleaned.startIndex..., in: cleaned)
                    cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
                }
            }
        }
        // Collapse triple+ newlines and trim
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        messages = []
        pendingActions = []
        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            sessionStorage = nil
            #endif
        }
    }

    func consumeAction(_ id: UUID) {
        pendingActions.removeAll { $0.id == id }
    }

    /// Used by the UI to inject a result message after a user-confirmed action.
    func appendAssistant(_ text: String) {
        messages.append(.assistant(text))
    }
}

// MARK: - Chat model types

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role: String { case user, assistant }

    static func user(_ text: String) -> AIChatMessage {
        AIChatMessage(role: .user, content: text)
    }
    static func assistant(_ text: String) -> AIChatMessage {
        AIChatMessage(role: .assistant, content: text)
    }
}

/// Inline action surfaced by tools — clicking it runs a destructive cleanup,
/// gated behind a user click for safety.
struct AIChatAction: Identifiable {
    let id = UUID()
    let label: String
    let systemImage: String
    let perform: @MainActor () async -> String   // returns a result message
}
