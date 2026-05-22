import SwiftUI

/// Horizontal chat bar pinned to the bottom of the Home scene.
/// AI responses don't render here — they appear as big chunky speech bubbles
/// attached to the apple character via `AISpeechBubble`.
struct ChatBottomBar: View {
    @StateObject private var assistant = AIAssistant.shared
    @State private var draft: String = ""
    @State private var autoFocusAttempted: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.stripeOrange)

            Text(">")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.stripeGreen)

            TextField(placeholder, text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .focused($focused)
                .opacity(assistant.isThinking ? 0.55 : 1)
                .onSubmit { send() }
                .onChange(of: assistant.isThinking) { _, thinking in
                    // When the model finishes thinking, snap focus back to the
                    // input so the user can keep chatting without re-clicking.
                    if !thinking { focused = true }
                }

            // Quick-suggestion pills shown when input is empty + no thinking
            if draft.isEmpty && !assistant.isThinking && assistant.messages.isEmpty {
                suggestionPills
            }

            Button(action: send) {
                Image(systemName: assistant.isThinking ? "ellipsis" : "return")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient.rainbow)
                    )
                    .opacity((draft.trimmingCharacters(in: .whitespaces).isEmpty || assistant.isThinking) ? 0.55 : 1)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || assistant.isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.14).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(LinearGradient.rainbow, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
    }

    private var placeholder: String {
        if assistant.isThinking { return "thinking…" }
        if assistant.messages.isEmpty { return "ask MacBroom anything…" }
        return "follow up…"
    }

    private var suggestionPills: some View {
        HStack(spacing: 6) {
            ForEach(quickPrompts, id: \.self) { prompt in
                Button {
                    draft = prompt
                    send()
                } label: {
                    Text(prompt)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private let quickPrompts = ["big files", "node_modules", "disk usage"]

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !assistant.isThinking else { return }
        draft = ""
        // Keep focus on the field — the user (and screencap automation) can
        // immediately send another message without re-clicking the bar.
        focused = true
        Task { await assistant.ask(text) }
    }
}

/// Large chunky speech bubble shown above the apple character for AI responses.
/// Stays visible until the user sends another message (then becomes "thinking…").
struct AISpeechBubble: View {
    let text: String
    let isThinking: Bool
    let actions: [AIChatAction]
    let onActionTapped: (AIChatAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Theme.stripeOrange)
                Text("MACBROOM AI")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .kerning(1.3)
                    .foregroundStyle(.white.opacity(0.70))
            }
            if isThinking {
                thinkingDots
            } else {
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !actions.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(actions) { action in
                        Button {
                            onActionTapped(action)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: action.systemImage)
                                    .font(.system(size: 11, weight: .bold))
                                Text(action.label)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(LinearGradient.rainbow)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.white.opacity(0.30), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LinearGradient.rainbow, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
        .overlay(alignment: .bottomLeading) {
            BubbleTail()
                .fill(LinearGradient.rainbow)
                .frame(width: 18, height: 12)
                .offset(x: 28, y: 11)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
    }

    private var thinkingDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.stripeOrange)
                    .frame(width: 7, height: 7)
                    .opacity(0.8)
                    .scaleEffect(1.0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: isThinking
                    )
            }
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX * 0.30, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
