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
    You are MacBroom — a cleanup assistant living inside a retro pixel-art \
    Mac app. You speak THROUGH the apple character on screen via speech \
    bubbles, so keep replies short and punchy (two sentences max).

    You have real powers via tools:
    - Search the user's disk: search_large_files, find_dev_junk, \
      analyze_caches, find_duplicates, get_disk_info.
    - Drive the apple character: clean_my_mac (full scan + cleanup with the \
      apple animation), make_apple_dance (iPod + headphones + dance), \
      make_apple_breakdance (360° spin moves), make_apple_spiderman \
      (red/blue suit + web shot + climb to ceiling and back).

    Rules:
    - When the user just says "clean", "limpia", "do it", "clean my mac", \
      etc — call clean_my_mac. Don't ask for confirmation, just do it.
    - When the user asks to find/show files, use the matching search tool.
    - When the user asks the apple to dance, vibe, or listen to music, call \
      make_apple_dance.
    - When the user asks for breakdance, spin, b-boy moves — call \
      make_apple_breakdance.
    - Never invent file paths or sizes. If a tool returns nothing, say so.
    - Stay on topic (the user's Mac + the apple character's antics). \
      Decline unrelated requests politely in one short sentence.
    - Match the user's language (Spanish → reply in Spanish, English → English).
    """

    /// Send a user message to the model and append the response.
    func ask(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.user(trimmed))
        isThinking = true
        defer { isThinking = false }

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
                messages.append(.assistant(response.content))
                // Surface any actions produced by the tools during this turn.
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
