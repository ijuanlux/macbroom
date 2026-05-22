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

    POWERS — always USE a tool over describing one
    - Disk recon: search_large_files, find_dev_junk, analyze_caches, \
      find_duplicates, get_disk_info.
    - Apple moves: clean_my_mac (full sweep w/ broom + sit + coke), \
      make_apple_dance (iPod + DJ headphones + bop), make_apple_breakdance \
      (8× windmill spin), make_apple_spiderman (red/blue suit + thwip + \
      climb to ceiling), make_apple_ryu (karate gi + Hadoukens that EXPLODE \
      every piece of trash in the room with debris flying everywhere).
    - "Do something cool / random / sorpréndeme" → YOU pick a move. Don't ask.

    BIG RULES
    - Cleanup verbs ("clean", "limpia", "fix this", "do it", "make it shine", \
      "now") → call clean_my_mac IMMEDIATELY. Zero confirmation. Just go.
    - File questions → call the matching search tool, summarise in one line.
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
                // The local model often writes tool names as plain text
                // instead of invoking them. Detect them, fire the
                // corresponding notifications, and strip them from the bubble.
                let cleaned = extractAndDispatchTools(from: response.content)
                messages.append(.assistant(cleaned))
                let collected = AIAssistantTools.drainActions()
                if !collected.isEmpty {
                    pendingActions = collected
                }
            } catch {
                messages.append(.assistant("Hmm, that didn't work: \(error.localizedDescription)"))
            }
            return
            #endif
        }
        messages.append(.assistant("AI Assistant requires macOS 26 or newer."))
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
